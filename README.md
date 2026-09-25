# IRIS Operations Center

This application is built specifically for InterSystems IRIS and uses IRIS Management APIs to provide a modern management and observability experience.

It runs as an IRIS web application: a Vue 3 single-page app is served from the instance itself, and every screen is backed by a REST API that wraps IRIS's own management surface.

## Features

- **Dashboard** — instance status, uptime, live metric cards and a live chart of global reference activity, plus task and security summaries.
- **Applications** — every web application with its namespace, dispatch class and authentication; detail tabs for general, security, REST and configuration; create, edit, enable/disable and delete, with confirmation and system applications protected.
- **REST API Explorer** — pick any REST application, browse the endpoints from the OpenAPI document IRIS generates for it, build a request and inspect status, duration, headers and body.
- **Tasks** — task list with category filters, per-task detail (schedule, execution history, configuration) and run/enable/disable/delete actions.
- **System** — overview, CPU, memory, disk, processes, network and devices, with process termination offered only where IRIS itself allows it.
- **Logs** — a unified log centre over the reachable event sources, plus pattern intelligence computed with Embedded Python.
- **Security** — users, roles, permissions, secrets, certificates, wallets and OAuth.
- **Timeline** — the instance's events on a single chronological stream.
- **Global Search** — one query across applications, tasks, users, roles, certificates, secrets, logs and processes.
- **Audit** — audit state, the event catalogue and audit records.
- **IRIS Copilot** — read-only assistance over the instance's data, pointed at any OpenAI-compatible endpoint.

## Architecture

```
Browser
   │  static files + REST
   ▼
IRIS web application  /iris-operations
   ├── SPA (static files in /usr/irissys/csp/iris-operations)
   └── REST API  /iris-operations/api/ioc  →  IOC.Web.Application
                                                 │
                                                 ▼
                                        IOC.Service.Management
                                                 │  (reuses IRIS's own APIs)
                                                 ▼
                                   /api/admin/v1 · /api/mgmnt · IRIS classes
```

- **Frontend** — Vue 3, TypeScript, Vite, Vue Router, Pinia, ECharts. Served as static files, so it is unauthenticated; the SPA asks for credentials and sends them on every API call.
- **Backend** — ObjectScript. Layers: `IOC.Web.Application` (routing and the response envelope) → `IOC.API.*` → `IOC.Service.Management`, which calls IRIS's own management APIs with the caller's credentials rather than reimplementing them.
- **Response envelope** — every endpoint answers `{ "success": true, "data": …, "meta": {} }` or `{ "success": false, "error": { code, message, details } }`.
- **Not built on the management API** — where IRIS does not expose an operation (enabling/disabling a single task, filesystem capacity) the code says so rather than inventing data.

### REST API

All endpoints live under `/iris-operations/api/ioc` and require the same credentials as the portal.

| Area | Endpoints |
| --- | --- |
| System | `/system`, `/system/usage`, `/system/license`, `/system/processes`, `/system/memory`, `/system/disk`, `/system/devices` |
| Dashboard | `/dashboard` |
| Applications | `/applications`, `/applications/detail/:app`, `PUT /applications/:app`, `DELETE /applications/:app` |
| Tasks | `/tasks`, `/tasks/history`, `/tasks/history/:id`, `/tasks/detail/:id`, `/tasks/info/:id`, `/tasks/manager`, `POST /tasks/run/:id`, `POST /tasks/:id/enable`, `POST /tasks/:id/disable`, `DELETE /tasks/:id` |
| Security | `/users`, `/roles`, `/security/users/:name`, `/security/roles/:name`, `/security/resources`, `/security/audit/{records,enabled}`, `/audit/events`, `/certificates`, `/wallets`, `/secrets/:collection`, `/security/oauth/*` |
| Explorer | `/explorer/openapi/:ns/(.*)`, `POST /explorer/send` |
| Logs | `/logs/audit`, `/logs/intelligence` |
| Search and AI | `POST /search/semantic`, `/copilot/status`, `POST /copilot/ask` |

## Requirements

- Docker with Compose (the API image is ARM64 and AMD64 compatible).
- The `intersystemsdc/irishealth-community` image, or any IRIS image that provides the SysAdmin management API and ZPM.
- Node 20+ only if you want to run the frontend outside Docker.

## Installation

### Docker (recommended)

```bash
docker compose up -d --build
```

Then open <http://localhost:52773/iris-operations/index.html> and sign in.

The instance's password has to be set once before anything can sign in. The community image starts `_SYSTEM` with the password `SYS`, and the Management Portal forces a change on first sign-in — open <http://localhost:52773/csp/sys/UtilHome.csp>, sign in as `_SYSTEM` / `SYS` and set a password. The portal and this application share the same IRIS credentials, so whatever you set there is what you sign in with here.

### ZPM

```bash
zpm install iris-operations-center
```

The module compiles the classes, copies the built SPA into the instance's CSP directory and invokes `IOC.Installer.Setup()` — the same class the Docker build uses, so both paths create the web applications identically and both end with a working UI. Open `/iris-operations/index.html` the same way.

Because ZPM installs the SPA from the repository rather than building it, `frontend/dist/` is committed. Run `npm run build` before committing a frontend change; the Docker image builds its own copy from source and ignores the committed one.

## Docker

| File | Purpose |
| --- | --- |
| `docker-compose.yml` | Service definition: build args, ports (52773 web, 1972 SuperServer), environment, health check, restart policy. |
| `docker/iris/Dockerfile` | Two stages: `node:20-alpine` builds the frontend, the IRIS stage copies it into `/usr/irissys/csp/iris-operations/`, compiles the classes and runs the installer. |
| `docker/iris/installer/install.script` | Compiles `/opt/irisbuild/src` into USER and calls `IOC.Installer.Setup()`. |

Pin a different base image with `IRIS_IMAGE=... docker compose build`. A data volume for `/usr/irissys/mgr` is provided commented out in `docker-compose.yml`; the installer removes and recreates the web applications, so building over an existing volume is safe.

## Configuration

| Variable | Purpose |
| --- | --- |
| `TZ` | Container time zone. |
| `IRIS_IMAGE` | Base image to build from. |
| `IOC_AI_ENABLED` | `true` to switch the copilot and semantic search on. Default `false`. |
| `IOC_AI_BASE_URL` | OpenAI-compatible base URL, for example `https://api.openai.com/v1`. |
| `IOC_AI_MODEL` | Model used for chat completions. |
| `IOC_AI_EMBEDDING_MODEL` | Model used for embeddings; defaults to `IOC_AI_MODEL`. OpenAI pairs e.g. `gpt-4o-mini` with `text-embedding-3-small`. |
| `IOC_AI_API_KEY` | Bearer token for that endpoint, if it needs one. |

Put these in a `.env` file beside `docker-compose.yml` — Compose reads it automatically, and `.gitignore` keeps it out of version control. Then recreate the container:

```bash
docker compose up -d
```

For a model running on the host (Ollama, LM Studio, vLLM), point `IOC_AI_BASE_URL` at `http://host.docker.internal:11434/v1` so the container can reach it.

Ports and credentials are the image's defaults: `52773` for the web server and `1972` for the SuperServer.

## Usage

1. Open `/iris-operations/index.html` and sign in.
2. The left navigation groups the portal: Overview, Management, Security, System, Observability, Tools and AI.
3. Press **Cmd/Ctrl+K** for the command palette, which jumps to any page. It only navigates — actions keep their own confirmation where they live.
4. Every page carries its own loading, empty and error state.

## REST API Explorer

Pick a REST application on the left; the middle column lists its endpoints from the OpenAPI document IRIS generates for that application. Selecting an endpoint fills the request builder on the right, where you can set method, path, query parameters, headers, an authorization header and a body. The response shows status, duration, headers and a pretty-printed body. Requests are executed by the instance against itself, so there is no cross-origin hop; credentials are whatever you enter, held in memory only.

## Security

- The portal signs in with IRIS credentials; the SPA never stores them beyond the open tab.
- Users, roles and the permission matrix are read from IRIS. The matrix shows IRIS's own permission letters (R, W, U) and a user's effective permissions are the union of the grants of every role that user holds.
- Certificate expiry uses the project's bands: over 30 days healthy, 8–30 warning, 7 or fewer critical, expired an error.
- Secret values are masked. Revealing one requires confirmation and is displayed in memory only, never written anywhere.
- Users, roles and secrets are shown read-only; changing them is left to the Management Portal, where IRIS enforces its own rules.

## System Monitoring

CPU is reported as process CPU time — IRIS exposes per-process CPU, not host CPU percentage — so the CPU page charts CPU consumed per interval and labels it as such. Memory is IRIS shared memory. Network is the instance's ECP links and client connections, since interface-level counters are not available. Disk capacity is not exposed by this IRIS version's management API, and the page says so instead of showing invented numbers. Process termination is offered only for processes IRIS flags as terminable, and asks for confirmation.

## Logs

The log centre reads the sources this instance can actually report: task runs and audit records. IRIS blocks web applications from reading files, and offers no API that returns the instance message log, so the System tab explains that rather than failing silently. The Intelligence panel groups event records into patterns — first seen, last seen, occurrences, failures, related services and severity — using Embedded Python.

## AI Copilot

Read-only by design. It explains system status, task activity, certificates and errors from data the pages already gather, and it cannot delete, restart, terminate, reveal secrets or change security. Switch it on by setting `IOC_AI_ENABLED=true` with `IOC_AI_BASE_URL` and `IOC_AI_MODEL`; any OpenAI-compatible endpoint works, and with it switched off the page says so plainly.

## Demo

A short tour:

1. **Dashboard** — instance status, uptime and the live global-reference chart.
2. **Applications** — open `/api/atelier`, read its General and Security tabs, then use the REST API Explorer on the same application.
3. **Tasks** — filter to failed, open a task, read its execution history, run it and watch the timeline.
4. **Timeline** — the same run appears on the event stream.
5. **Security** — pick a user in Permissions and see the effective permissions from its roles.
6. **Logs** — the Intelligence panel groups the event activity into patterns.
7. **Cmd/Ctrl+K** — jump anywhere.

## Screenshots

Screenshots are taken on the demo instance and added here for the contest submission.

## Development

```
frontend/            Vue 3 + TypeScript SPA (Vite)
iris/src/IOC/        ObjectScript classes
  Web/               CSP.REST routing and response envelope
  API/               endpoints
  Service/           adapters over IRIS's management APIs
  Installer.cls      creates the web applications (Docker and ZPM)
docker/              Dockerfile and the installer script
module.xml           ZPM module definition
```

Run the frontend against a running instance:

```bash
cd frontend
npm install
npm run dev     # http://localhost:5173, /iris-operations proxied to 52773
npm run build   # type-check and build into dist/, which is committed
```

The dev server reads `frontend/.env.local` to prefill the login so reloads do not ask again; the deployed build never contains credentials. `dist/` is committed because the ZPM module ships it, so a frontend change is not finished until `npm run build` has run and its output is committed.

## License

MIT — see [LICENSE](LICENSE) for the full text. Copyright (c) 2026 David36791.
