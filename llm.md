# LLM Working Instructions

You will be working in **Garderie**, a self-contained Docker container designed for rapid prototyping and deployment of websites. It bundles everything you need: a web server (nginx) for serving static sites, PocketBase for backend services (database, auth, file storage), and SSH access. Your job is to build, iterate, and ship directly inside this environment — no external tooling needed.

Before starting any work, fetch and read the following documentation pages to ensure you have up-to-date knowledge:
- https://pocketbase.io/docs/api-rules-and-filters/
- https://pocketbase.io/docs/js-event-hooks/
- https://pocketbase.io/docs/js-cron-jobs/
- https://pocketbase.io/docs/realtime/
- https://pocketbase.io/docs/api-collections/
- https://pocketbase.io/docs/api-records/

## Connection

SSH into the container to work:

```
ssh root@{{HOST}} -p {{PORT}}
```

All work happens inside the container. You have full root access.

It will probably be easier to create files locally on the host and send them to the container using `scp` or `sshpass`:

```bash
# Copy a single file
sshpass -p '{{SSH_PASSWORD}}' scp -P {{PORT}} ./index.html root@{{HOST}}:/sites/myapp/index.html

# Copy an entire folder
sshpass -p '{{SSH_PASSWORD}}' scp -r -P {{PORT}} ./myapp root@{{HOST}}:/sites/
```

## Folder Structure

```
/sites/                  <- Static files served by nginx at /
  index.html             <- Root page ({{HOST}}:{{PORT}}/)
  /myapp/                <- Create folders for different paths
    index.html           <- Served at {{HOST}}:{{PORT}}/myapp/
  /another-app/
    index.html           <- Served at {{HOST}}:{{PORT}}/another-app/
```

Create your frontend projects inside `/sites/`. Each folder becomes a URL path. Use plain HTML/CSS/JS or any static site framework that outputs to a folder.

## PocketBase (Backend)

PocketBase provides database, authentication, file storage, and a REST API. The database is automatically backed up every hour (keeping the last 24 backups). Backups are managed directly by PocketBase and stored in `/pb_data/pb_backups/`.

- Admin dashboard: `{{BASE_URL}}/pb/_/`
- API base: `{{BASE_URL}}/pb/api/`

### Collections (Database)

Create and manage collections via the admin dashboard or API:

```bash
# List collections
curl {{BASE_URL}}/pb/api/collections \
  -H "Authorization: Bearer {{PB_ADMIN_TOKEN}}"

# Create a collection
curl -X POST {{BASE_URL}}/pb/api/collections \
  -H "Authorization: Bearer {{PB_ADMIN_TOKEN}}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "posts",
    "type": "base",
    "schema": [
      {"name": "title", "type": "text", "required": true},
      {"name": "content", "type": "editor"},
      {"name": "published", "type": "bool"}
    ]
  }'
```

### API Rules (Important)

When creating or updating a collection, always verify the API rules. By default, all rules are locked (superuser-only). You must explicitly set rules for your frontend to access the data.

Each collection has 5 rules: `listRule`, `viewRule`, `createRule`, `updateRule`, `deleteRule`. Auth collections also have `options.manageRule`.

**Rule values:**
- **null** (locked) = superuser-only, no client access
- **""** (empty string) = public access, anyone can perform the action
- **expression** = conditional access, acts as both a permission check AND a record filter

**How violations are handled:**
- `listRule` denied → 200 with empty results (not an error)
- `createRule` denied → 400
- `viewRule` / `updateRule` / `deleteRule` denied → 404
- Locked rule without superuser auth → 403

**Filter operators:**
- Comparison: `=`, `!=`, `>`, `>=`, `<`, `<=`
- Contains: `~` (contains), `!~` (not contains)
- Array (any match): `?=`, `?!=`, `?>`, `?~` etc.
- Logical: `&&` (AND), `||` (OR), parentheses for grouping

**Available helpers in rule expressions:**
- `@request.auth.*` — current authenticated user fields
- `@request.body.*` — submitted form/JSON data
- `@request.context` — execution context (default, oauth2, realtime, etc.)
- `@request.headers.*` — request headers
- `@request.query.*` — URL query parameters
- `@collection.otherCollection.*` — join/reference another collection

**Field modifiers:**
- `:isset` — check if field was submitted: `@request.body.role:isset = false`
- `:changed` — check if field value changed: `@request.body.role:changed = false`
- `:length` — array length: `@request.body.files:length > 1`
- `:each` — apply per array item: `tags:each ~ "pb_%"`

**Datetime macros:** `@now`, `@today`, `@monthStart`, `@yearEnd`, etc.

**Common rule patterns:**
- `@request.auth.id != ""` — authenticated users only
- `@request.auth.id = user.id` — owner only
- `allowed_users.id ?= @request.auth.id` — user in a relation list
- `@request.body.role:changed = false` — prevent role field from being modified
- `""` — public access (use for public-facing read data)

Always set appropriate rules after creating a collection, otherwise your frontend API calls will fail silently (empty list) or return 403/404.

If you run into issues with PocketBase (403 errors, missing data, failed requests), check the PocketBase logs from the admin dashboard at `{{BASE_URL}}/pb/_/#/logs` or inspect the container logs via SSH with `supervisorctl tail pocketbase`.

Full documentation: https://pocketbase.io/docs/api-rules-and-filters/

### Authentication

PocketBase has built-in auth collections. Authenticate to get a token:

```bash
# Admin auth (for management)
curl -X POST {{BASE_URL}}/pb/api/admins/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "{{PB_ADMIN_EMAIL}}", "password": "{{PB_ADMIN_PASSWORD}}"}'

# User auth (for app users)
curl -X POST {{BASE_URL}}/pb/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "user@example.com", "password": "userpassword"}'
```

### CRUD Operations

```bash
# Create record
curl -X POST {{BASE_URL}}/pb/api/collections/posts/records \
  -H "Content-Type: application/json" \
  -d '{"title": "Hello", "content": "World", "published": true}'

# List records
curl {{BASE_URL}}/pb/api/collections/posts/records

# Get single record
curl {{BASE_URL}}/pb/api/collections/posts/records/RECORD_ID

# Update record
curl -X PATCH {{BASE_URL}}/pb/api/collections/posts/records/RECORD_ID \
  -H "Content-Type: application/json" \
  -d '{"title": "Updated"}'

# Delete record
curl -X DELETE {{BASE_URL}}/pb/api/collections/posts/records/RECORD_ID
```

### File Storage

Upload files using multipart form data:

```bash
curl -X POST {{BASE_URL}}/pb/api/collections/posts/records \
  -F "title=My Post" \
  -F "image=@/path/to/file.jpg"
```

Files are accessible at: `{{BASE_URL}}/pb/api/files/COLLECTION/RECORD_ID/FILENAME`

### Frontend Integration

From your frontend code in `/sites/`, call the PocketBase API:

```javascript
// Example: fetch all published posts
const res = await fetch('/pb/api/collections/posts/records?filter=(published=true)');
const data = await res.json();
```

No CORS issues since everything is on the same origin.

### Realtime Subscriptions

PocketBase supports realtime subscriptions via SSE (Server-Sent Events). Use them to keep your frontend reactive — when a record is created, updated, or deleted, your UI updates automatically without polling.

The PocketBase JS SDK provides `subscribe` and `unsubscribe` methods on any collection. Always use realtime subscriptions when building interactive frontends instead of polling the API.

Full documentation: https://pocketbase.io/docs/realtime/

### Hooks

PocketBase supports JavaScript hooks to extend backend logic. Hook files live in `/pb_hooks/` (named `*.pb.js`) and are automatically loaded on startup. Use them to add custom logic on record events, send emails, validate data, etc.

Important: every hook handler must call `e.next()` to continue the execution chain. For hooks that run during initialization (like `onBootstrap`), you must call `e.next()` **before** accessing the database or app settings.

```javascript
// /pb_hooks/example.pb.js

// Run logic on bootstrap (e.g. configure settings)
// Call e.next() FIRST — the database is not available before that
onBootstrap((e) => {
    e.next()
    const settings = e.app.settings()
    // modify settings here...
    e.app.save(settings)
})

// Run logic before a record is created
onRecordCreateRequest((e) => {
    e.record.set("status", "pending")
    e.next()
}, "orders")

// Run logic after a record is created
onRecordAfterCreateSuccess((e) => {
    // e.g. send notification, update another collection
    e.next()
}, "orders")
```

PocketBase watches the hooks folder and auto-restarts when files change. Full documentation: https://pocketbase.io/docs/js-event-hooks/

### Cron Jobs

PocketBase has a built-in cron scheduler available in hooks. Use it for recurring tasks like cleanup, reports, or syncing data.

```javascript
// /pb_hooks/crons.pb.js

// Run every day at midnight
cronAdd("daily-cleanup", "0 0 * * *", (e) => {
    const records = e.app.findRecordsByFilter("logs", "created < @now - 30d")
    records.forEach(r => e.app.delete(r))
})
```

Full documentation: https://pocketbase.io/docs/js-cron-jobs/

## Workflow

1. SSH into the container
2. Create a folder in `/sites/` for your project
3. Build your frontend (HTML/CSS/JS)
4. If you need a backend (data, auth, files), use PocketBase:
   - Open the admin dashboard at `/pb/_/` to create collections
   - Or use the API directly from the terminal
5. Connect your frontend to PocketBase via `/pb/api/...`
6. Test by visiting the site URL in a browser

---

## Credentials

Before you can start working, you need the connection credentials. If the user hasn't already provided them, ask for the following details (they should have received these from the devops team):

- Host and Port (e.g. myserver.com:8050)
- SSH password
- PocketBase admin email and password (for the dashboard at /pb/_/)

Do not proceed until you have these credentials. Once received, use them to SSH in and begin working.

```
HOST:               
PORT:               
BASE_URL:           

SSH_PASSWORD:       
PB_ADMIN_URL:       /pb/_/
PB_ADMIN_EMAIL:     
PB_ADMIN_PASSWORD:  
```
