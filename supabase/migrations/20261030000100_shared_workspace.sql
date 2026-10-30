-- Shared, multi-tenant project workspace foundation for Orbit.
-- Apply with `supabase db push` after linking the intended Supabase project.

create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Orbit user',
  email text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 80),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  unique (id, created_by)
);

create table public.workspace_members (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('owner', 'admin', 'member', 'viewer')),
  joined_at timestamptz not null default now(),
  primary key (workspace_id, user_id)
);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  name text not null check (length(trim(name)) between 2 and 80),
  key text not null check (key ~ '^[A-Z][A-Z0-9]{1,7}$'),
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id, key),
  unique (id, workspace_id)
);

create table public.project_issue_counters (
  project_id uuid primary key references public.projects(id) on delete cascade,
  last_value bigint not null default 0 check (last_value >= 0)
);

create table public.issues (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  project_id uuid not null,
  issue_key text not null,
  issue_type text not null default 'task' check (issue_type in ('task', 'story', 'bug', 'epic')),
  summary text not null check (length(trim(summary)) between 1 and 240),
  description text not null default '',
  status text not null default 'todo' check (status in ('todo', 'inprogress', 'review', 'done')),
  priority text not null default 'medium' check (priority in ('highest', 'high', 'medium', 'low')),
  assignee_id uuid references public.profiles(id) on delete set null,
  due_date date,
  story_points smallint check (story_points between 0 and 100),
  labels text[] not null default '{}',
  sort_order bigint not null default 0,
  created_by uuid not null default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (project_id, workspace_id) references public.projects(id, workspace_id) on delete cascade,
  unique (project_id, issue_key),
  unique (id, workspace_id)
);

create table public.issue_comments (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  issue_id uuid not null,
  author_id uuid not null default auth.uid() references public.profiles(id),
  body text not null check (length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now(),
  foreign key (issue_id, workspace_id) references public.issues(id, workspace_id) on delete cascade
);

create table public.workspace_invitations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  email text not null,
  role text not null check (role in ('admin', 'member', 'viewer')),
  token_hash text not null unique,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  accepted_at timestamptz,
  unique (workspace_id, email)
);

create table public.audit_events (
  id bigint generated always as identity primary key,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  event_type text not null,
  entity_type text not null,
  entity_id text not null,
  before_data jsonb,
  after_data jsonb,
  created_at timestamptz not null default now()
);

create index issues_workspace_project_status_idx on public.issues(workspace_id, project_id, status, sort_order);
create index issues_assignee_idx on public.issues(workspace_id, assignee_id) where assignee_id is not null;
create index comments_issue_created_idx on public.issue_comments(issue_id, created_at);
create index audit_events_workspace_created_idx on public.audit_events(workspace_id, created_at desc);
create index invitations_email_idx on public.workspace_invitations(lower(email), expires_at) where accepted_at is null;

create or replace function public.is_workspace_member(target_workspace uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.workspace_members wm
    where wm.workspace_id = target_workspace and wm.user_id = (select auth.uid())
  );
$$;

create or replace function public.has_workspace_role(target_workspace uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.workspace_members wm
    where wm.workspace_id = target_workspace
      and wm.user_id = (select auth.uid())
      and wm.role = any(allowed_roles)
  );
$$;

create or replace function public.can_edit_workspace(target_workspace uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.has_workspace_role(target_workspace, array['owner', 'admin', 'member']);
$$;

revoke all on function public.is_workspace_member(uuid) from public, anon;
revoke all on function public.has_workspace_role(uuid, text[]) from public, anon;
revoke all on function public.can_edit_workspace(uuid) from public, anon;
grant execute on function public.is_workspace_member(uuid) to authenticated;
grant execute on function public.has_workspace_role(uuid, text[]) to authenticated;
grant execute on function public.can_edit_workspace(uuid) to authenticated;

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger projects_set_updated_at before update on public.projects
for each row execute function public.set_updated_at();
create trigger issues_set_updated_at before update on public.issues
for each row execute function public.set_updated_at();

create or replace function public.assign_issue_key()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  project_prefix text;
  next_number bigint;
begin
  select p.key into project_prefix
  from public.projects p where p.id = new.project_id and p.workspace_id = new.workspace_id;
  if project_prefix is null then raise exception 'Project not found in workspace'; end if;
  insert into public.project_issue_counters(project_id, last_value)
  values (new.project_id, 1)
  on conflict (project_id) do update
    set last_value = public.project_issue_counters.last_value + 1
  returning last_value into next_number;
  new.issue_key := project_prefix || '-' || next_number::text;
  new.created_by := coalesce(new.created_by, auth.uid());
  return new;
end;
$$;
create trigger issues_assign_key before insert on public.issues
for each row execute function public.assign_issue_key();

create or replace function public.check_issue_assignee_membership()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.assignee_id is not null and not exists (
    select 1 from public.workspace_members wm
    where wm.workspace_id = new.workspace_id and wm.user_id = new.assignee_id
  ) then
    raise exception 'Assignee must be a member of this workspace';
  end if;
  return new;
end;
$$;
create trigger issues_check_assignee before insert or update of assignee_id, workspace_id on public.issues
for each row execute function public.check_issue_assignee_membership();

create or replace function public.audit_workspace_row()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  row_before jsonb;
  row_after jsonb;
  target_workspace uuid;
  target_id text;
  operation text;
begin
  if tg_op = 'INSERT' then
    row_after := to_jsonb(new);
    target_workspace := (row_after ->> 'workspace_id')::uuid;
    target_id := coalesce(row_after ->> 'id', row_after ->> 'user_id');
    operation := 'created';
  elsif tg_op = 'UPDATE' then
    row_before := to_jsonb(old);
    row_after := to_jsonb(new);
    target_workspace := (row_after ->> 'workspace_id')::uuid;
    target_id := coalesce(row_after ->> 'id', row_after ->> 'user_id');
    operation := 'updated';
  else
    row_before := to_jsonb(old);
    target_workspace := (row_before ->> 'workspace_id')::uuid;
    target_id := coalesce(row_before ->> 'id', row_before ->> 'user_id');
    operation := 'deleted';
  end if;
  insert into public.audit_events(workspace_id, actor_id, event_type, entity_type, entity_id, before_data, after_data)
  values (target_workspace, auth.uid(), operation, tg_table_name, target_id, row_before, row_after);
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger projects_audit after insert or update or delete on public.projects
for each row execute function public.audit_workspace_row();
create trigger issues_audit after insert or update or delete on public.issues
for each row execute function public.audit_workspace_row();
create trigger comments_audit after insert or update or delete on public.issue_comments
for each row execute function public.audit_workspace_row();
create trigger workspace_members_audit after insert or update or delete on public.workspace_members
for each row execute function public.audit_workspace_row();
create trigger invitations_audit after insert or update or delete on public.workspace_invitations
for each row execute function public.audit_workspace_row();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  new_workspace uuid;
  person_name text;
begin
  person_name := coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), split_part(new.email, '@', 1), 'Orbit user');
  insert into public.profiles(id, display_name, email) values (new.id, person_name, lower(new.email));
  insert into public.workspaces(name, created_by) values (left(person_name || '''s workspace', 80), new.id) returning id into new_workspace;
  insert into public.workspace_members(workspace_id, user_id, role) values (new_workspace, new.id, 'owner');
  insert into public.projects(workspace_id, name, key, created_by) values (new_workspace, 'My first project', 'FIRST', new.id);
  return new;
end;
$$;
create trigger auth_user_created_orbit after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.create_workspace_invitation(p_workspace_id uuid, p_email text, p_role text)
returns table(invitation_token text, expires_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  raw_token text := gen_random_uuid()::text || gen_random_uuid()::text;
  invite_expiry timestamptz := now() + interval '7 days';
  normalized_email text := lower(trim(p_email));
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not public.has_workspace_role(p_workspace_id, array['owner', 'admin']) then raise exception 'Workspace administrator required'; end if;
  if p_role not in ('admin', 'member', 'viewer') then raise exception 'Invalid invitation role'; end if;
  if p_role = 'admin' and not public.has_workspace_role(p_workspace_id, array['owner']) then raise exception 'Only workspace owners can invite administrators'; end if;
  if normalized_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'Enter a valid email'; end if;
  insert into public.workspace_invitations(workspace_id, email, role, token_hash, created_by, expires_at)
  values (p_workspace_id, normalized_email, p_role, encode(extensions.digest(raw_token, 'sha256'), 'hex'), auth.uid(), invite_expiry)
  on conflict (workspace_id, email) do update set role = excluded.role, token_hash = excluded.token_hash,
    created_by = excluded.created_by, created_at = now(), expires_at = excluded.expires_at, accepted_at = null;
  return query select raw_token, invite_expiry;
end;
$$;

create or replace function public.accept_workspace_invitation(p_token text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  inviting_user uuid := auth.uid();
  user_email text;
  target_invite public.workspace_invitations%rowtype;
begin
  if inviting_user is null then raise exception 'Sign in to accept this invitation'; end if;
  select lower(email) into user_email from auth.users where id = inviting_user and email_confirmed_at is not null;
  if user_email is null then raise exception 'Verify your email before accepting an invitation'; end if;
  select * into target_invite from public.workspace_invitations
  where token_hash = encode(extensions.digest(p_token, 'sha256'), 'hex')
    and lower(email) = user_email and accepted_at is null and expires_at > now()
  for update;
  if not found then raise exception 'Invitation is invalid, expired, or for another email'; end if;
  insert into public.workspace_members(workspace_id, user_id, role)
  values (target_invite.workspace_id, inviting_user, target_invite.role)
  on conflict (workspace_id, user_id) do nothing;
  update public.workspace_invitations set accepted_at = now() where id = target_invite.id;
  return target_invite.workspace_id;
end;
$$;

revoke all on function public.create_workspace_invitation(uuid, text, text) from public, anon;
revoke all on function public.accept_workspace_invitation(text) from public, anon;
grant execute on function public.create_workspace_invitation(uuid, text, text) to authenticated;
grant execute on function public.accept_workspace_invitation(text) to authenticated;

alter table public.profiles enable row level security;
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.projects enable row level security;
alter table public.project_issue_counters enable row level security;
alter table public.issues enable row level security;
alter table public.issue_comments enable row level security;
alter table public.workspace_invitations enable row level security;
alter table public.audit_events enable row level security;

create policy profiles_read_workspace_members on public.profiles for select to authenticated
using (id = (select auth.uid()) or exists (
  select 1 from public.workspace_members mine
  join public.workspace_members theirs on theirs.workspace_id = mine.workspace_id
  where mine.user_id = (select auth.uid()) and theirs.user_id = profiles.id
));
create policy profiles_update_self on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy workspaces_read_members on public.workspaces for select to authenticated
using (public.is_workspace_member(id));
create policy workspaces_update_admins on public.workspaces for update to authenticated
using (public.has_workspace_role(id, array['owner', 'admin']))
with check (public.has_workspace_role(id, array['owner', 'admin']));

create policy workspace_members_read_members on public.workspace_members for select to authenticated
using (public.is_workspace_member(workspace_id));
-- Memberships are visible to workspace members. Role assignment is restricted
-- to the invitation acceptance RPC; this prevents admins changing their own role.

create policy projects_read_members on public.projects for select to authenticated
using (public.is_workspace_member(workspace_id));
create policy projects_create_editors on public.projects for insert to authenticated
with check (public.can_edit_workspace(workspace_id) and created_by = (select auth.uid()));
create policy projects_update_admins on public.projects for update to authenticated
using (public.has_workspace_role(workspace_id, array['owner', 'admin']))
with check (public.has_workspace_role(workspace_id, array['owner', 'admin']));
create policy projects_delete_admins on public.projects for delete to authenticated
using (public.has_workspace_role(workspace_id, array['owner', 'admin']));

create policy issues_read_members on public.issues for select to authenticated
using (public.is_workspace_member(workspace_id));
create policy issues_create_editors on public.issues for insert to authenticated
with check (public.can_edit_workspace(workspace_id) and created_by = (select auth.uid()));
create policy issues_update_editors on public.issues for update to authenticated
using (public.can_edit_workspace(workspace_id)) with check (public.can_edit_workspace(workspace_id));
create policy issues_delete_admins on public.issues for delete to authenticated
using (public.has_workspace_role(workspace_id, array['owner', 'admin']));

create policy comments_read_members on public.issue_comments for select to authenticated
using (public.is_workspace_member(workspace_id));
create policy comments_create_members on public.issue_comments for insert to authenticated
with check (public.can_edit_workspace(workspace_id) and author_id = (select auth.uid()));

create policy invitations_admin_read on public.workspace_invitations for select to authenticated
using (public.has_workspace_role(workspace_id, array['owner', 'admin']));

create policy audit_read_admins on public.audit_events for select to authenticated
using (public.has_workspace_role(workspace_id, array['owner', 'admin']));

grant select, update on public.profiles to authenticated;
grant select, update on public.workspaces to authenticated;
grant select on public.workspace_members to authenticated;
grant insert, select, update, delete on public.projects to authenticated;
grant select, insert, update, delete on public.issues to authenticated;
grant select, insert on public.issue_comments to authenticated;
grant select on public.workspace_invitations, public.audit_events to authenticated;

-- Keep the shared UI fresh for all signed-in workspace members.
do $$
declare
  table_name text;
begin
  foreach table_name in array array['projects', 'issues', 'issue_comments', 'workspace_members'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;
