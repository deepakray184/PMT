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

The frontend is configured for project `yevxvvwncmlxobxuybes`. Add the project's **publishable key** (`sb_publishable_…`) to `config.js`:

```js
window.ORBIT_CONFIG = {
  supabaseUrl: 'https://yevxvvwncmlxobxuybes.supabase.co',
  publishableKey: 'sb_publishable_your_project_key'
};
```

The publishable key is intended for browser use; never put a secret or `service_role` key in `config.js`.

Apply the migration from this directory using the Supabase CLI linked to the intended project:

```sh
supabase link --project-ref yevxvvwncmlxobxuybes
supabase db push
```

Then configure Supabase Auth email confirmation and the allowed site/redirect URLs for both the deployed Pages URL and local development URL. New accounts receive a personal workspace and starter project. The first owner can create projects and invite teammates. Admins can invite members/viewers; only owners can issue admin invitations.

## Run locally

Requires Node.js 18 or newer. No package install is needed.

```sh
npm start
npm test
```

## Deployment and operational requirements

GitHub Pages is a static host. The Supabase project is responsible for database availability, backups, identity, and authorization. Before production use, configure MFA and organization identity policy, SMTP and email-confirmation behavior, review backup/restore coverage, and run security tests against a non-production Supabase project. This starter does not implement Microsoft Entra SSO, SCIM provisioning, file storage, or enterprise support/availability controls. The included database migration has not been applied to the live project from this repository.
