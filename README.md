# Orbit Project Workspace

Orbit is a static project management interface backed by Supabase for authentication, shared workspace data, role-based access, invitations, and audit events. GitHub Pages serves the frontend; Supabase provides the application backend.

## Features

- Email and password sign-in with Supabase Auth.
- Multi-workspace membership with owner, admin, member, and viewer roles.
- Shared projects, issues, comments, issue keys, and realtime issue/project refresh.
- Project creation, issue create/edit/delete, board status changes, search, filters, overview, list, and timeline views.
- Workspace invitation links restricted to the invited email and valid for seven days.
- Database row-level security and append-only audit events for core project activity.

## Configure Supabase

The frontend is configured for project `yevxvvwncmlxobxuybes` in `config.js`. Its `sb_publishable_…` key is browser-safe and is intentionally delivered to site visitors. Never use a Supabase secret or `service_role` key in this file.

```js
window.ORBIT_CONFIG = {
  supabaseUrl: 'https://yevxvvwncmlxobxuybes.supabase.co',
  publishableKey: 'sb_publishable_…'
};
```

The shared workspace migration has been applied to the selected Supabase project. It creates Orbit-specific profile data in `orbit_profiles` so it does not overwrite the existing SplitMoney `profiles` table, and it bootstraps workspaces for existing project users. For a different Supabase project, review the migration first because the bootstrap step reads the existing SplitMoney profiles table, then apply it using the Supabase CLI:

```sh
supabase link --project-ref yevxvvwncmlxobxuybes
supabase db push
```

Configure Supabase Auth email confirmation and allowed site/redirect URLs for the deployed Pages URL and local development URL. New accounts receive a personal workspace and starter project. Workspace owners can create projects and invite teammates. Admins can invite members/viewers; only owners can issue admin invitations.

## Run locally

Requires Node.js 18 or newer. No package install is needed.

```sh
npm start
npm test
```

## Deployment and operational requirements

GitHub Pages is a static host. The Supabase project is responsible for database availability, backups, identity, and authorization. Before production use, configure MFA and organization identity policy, SMTP and email-confirmation behavior, review backup/restore coverage, and run security tests against a non-production Supabase project. This starter does not implement Microsoft Entra SSO, SCIM provisioning, file storage, or enterprise support/availability controls.

## Workspace lifecycle and access model

- Sign-up creates a private personal workspace and starter project. A verified, signed-in user can also create more workspaces from **＋ New workspace**.
- Workspace creation is a server-side transaction: the creator becomes the `owner`, a starter project is added, and the creation is recorded in the workspace audit log. A failed transaction does not leave a partial workspace.
- A workspace is visible only to its members. Users switch only among memberships returned by the database; the browser's stored last workspace is a convenience and is never an authorization check.
- `owner` can manage projects, invite any supported role, and invite admins. `admin` can manage projects and invite members/viewers. `member` can create and edit work items and comments. `viewer` is read-only. Database row-level security enforces these boundaries.
- Invitations are limited to the invited email, require a confirmed account, and expire after seven days. Membership roles cannot be changed by direct client writes.

### Rollout

The workspace creation UI depends on `20261031000100_workspace_lifecycle.sql`. Apply all checked-in migrations to the selected Supabase project, then deploy the frontend commit. Verify signup, creating a second workspace, switching between workspaces, and inviting a second test account in a non-production project before enabling organization-wide use.

This establishes multi-tenant isolation and core role controls, but it is not by itself a complete Jira replacement or a certification of enterprise readiness. Entra SSO/SCIM, MFA enforcement, automated provisioning/deprovisioning, custom retention and backup validation, support/availability commitments, and security review remain deployment requirements. Do not put sensitive or regulated data in the app until those controls are configured and verified.
