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
