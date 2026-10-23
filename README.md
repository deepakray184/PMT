# Orbit Project Workspace

Orbit is a lightweight, browser-based project planning app with a Jira-style board. It runs as a static site and can be hosted on GitHub Pages. It is a useful personal or prototype workspace, but it is not a full Jira replacement: data stays in the browser and is not shared with a team.

## Features

- **Multiple projects:** create projects, choose a project key, and switch between separate issue boards. If you leave the key blank, Orbit generates one from the project name.
- **Issue tracking:** create and edit tasks, stories, bugs, and epics with descriptions, status, priority, assignee, due date, story points, and labels.
- **Kanban:** move issues between To do, In progress, In review, and Done by dragging cards. Create issues from a column or from the project header.
- **Issue details and comments:** select a card to view its details and add comments. Use the card menu to edit, delete, or change an issue's status.
- **Project views:** switch among Overview, Board, List, and Timeline.
- **Search and filters:** search issue keys, summaries, descriptions, labels, and assignee names. Filter by priority, assignee, or issue type.
- **Appearance and shortcuts:** toggle dark or light mode. Use `Ctrl/⌘ + K` to focus search and `Ctrl/⌘ + N` to create an issue.
- **Local persistence:** projects, issues, and comments are saved in the current browser's local storage.

## Run locally

Requirements: Node.js 18 or newer. The app uses Node's built-in modules; no `npm install` is needed.

```sh
npm start
```

Open the local URL printed in the terminal (by default, `http://127.0.0.1:8000`). To use another port:

```sh
PORT=3000 npm start
```

Run the automated server and asset smoke checks with:

```sh
npm test
```

## Deploy to GitHub Pages

The app's `index.html`, `styles.css`, and `script.js` are at the repository root. Configure GitHub Pages to publish the `main` branch from the root folder. The GitHub Actions workflow runs the smoke checks on pushes and pull requests; it does not publish the site itself.

## Data, privacy, and team use

Orbit currently has no server-side database or authentication. The profile and assignee choices are demo UI values, not verified user accounts. Each browser stores its own project data; it does not synchronize across browsers or people. Clearing site data can remove saved projects and issues.

Do not use this version for confidential company information or as a system of record. A corporate deployment needs a secured backend, an identity provider, project-level roles and permissions, shared durable storage, backups, and audit history. GitHub Pages alone does not provide those services.

## Repository structure

- `index.html` — page structure and dialogs
- `styles.css` — responsive styling and themes
- `script.js` — project, issue, view, filter, and local-storage behavior
- `server.js` — small static-file server for local development
- `smoke.test.js` — automated HTTP and asset checks
- `.github/workflows/webpack.yml` — CI smoke checks (the historical filename remains; Webpack is no longer used)
