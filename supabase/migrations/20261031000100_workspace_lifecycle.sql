-- Allow every authenticated user to create an isolated workspace.
-- Membership and starter project creation happen atomically under a definer RPC.
create or replace function public.create_workspace(p_name text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  new_workspace uuid;
  clean_name text := trim(coalesce(p_name, ''));
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'Authentication required';
  end if;
  if length(clean_name) < 2 or length(clean_name) > 80 then
    raise exception 'Workspace name must be between 2 and 80 characters';
  end if;
  if not exists (select 1 from public.orbit_profiles p where p.id = actor) then
    raise exception 'User profile is not ready; sign out and back in, then retry';
  end if;

  insert into public.workspaces(name, created_by)
  values (clean_name, actor)
  returning id into new_workspace;

  insert into public.workspace_members(workspace_id, user_id, role)
  values (new_workspace, actor, 'owner');

  insert into public.projects(workspace_id, name, key, created_by)
  values (new_workspace, 'My first project', 'FIRST', actor);

  insert into public.audit_events(workspace_id, actor_id, event_type, entity_type, entity_id, after_data)
  values (new_workspace, actor, 'created', 'workspace', new_workspace::text,
          jsonb_build_object('name', clean_name));

  return new_workspace;
end;
$$;

revoke all on function public.create_workspace(text) from public, anon;
grant execute on function public.create_workspace(text) to authenticated;
