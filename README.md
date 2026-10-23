# Orbit Project Workspace

A responsive project planning interface with Kanban, list, timeline, overview, and issue detail views.

## Current features

- Multiple projects with separate issue boards and configurable issue keys.
- Create, edit, comment on, search, and filter issues.
- Drag issues between workflow columns; track type, priority, owner, due date, labels, and story points.
- Browser-based persistence and dark/light appearance.
- Keyboard shortcuts: `⌘/Ctrl + K` to search and `⌘/Ctrl + N` to create an issue.

## Run locally

Requires Node.js 18 or newer. No package installation is needed.

```sh
npm start
```

Open the local URL printed by the server. Run the automated smoke checks with:

```sh
npm test
```

## Deployment and collaboration boundary

GitHub Pages can host this static interface, but it does not provide a shared database, user authentication, access controls, or an audit trail. Project and issue data currently stays in the browser's local storage and is not shared with colleagues or synchronized across devices. A production corporate deployment needs a server-side identity provider and database with authorization rules, backups, and audit logging before teams use it for company work.
