# Backend - Dev Notes

Run the web server without schedulers in development, and run the scheduler in a separate worker process.

Web server (disable scheduler):

```bash
DISABLE_SCHEDULER=1 npm run dev
```

Start scheduler worker in another terminal:

```bash
npm run worker
```

In production, prefer running the scheduler as a separate service or as a managed background job. Do not run heavy cron tasks in the same process as the web server.

Security: rotate any keys that were committed; add `.env` to `.gitignore` (already added) and avoid committing credentials.

---

## Stop tracking `.env` (safe, non-destructive)

To stop tracking the existing `backend/.env` file in git (safe):

```bash
# 1) Stage the .gitignore change and remove the file from the index only
git add backend/.gitignore
git rm --cached backend/.env
git commit -m "Stop tracking backend .env and add to .gitignore"

# 2) Push the commit to remote
git push origin main
```

This leaves `.env` in the repository history but prevents future commits from including it.

---

## Secure history removal (destructive) — BFG or git-filter-repo

If you need to remove `backend/.env` from the entire git history, you must rewrite history and force-push. Coordinate with all collaborators. Two recommended tools:

- BFG Repo-Cleaner (simpler): https://rtyley.github.io/bfg-repo-cleaner/
- git-filter-repo (recommended for advanced use): https://github.com/newren/git-filter-repo

Example BFG flow (you must have a fresh clone or backup):

```bash
# 1) Make a fresh clone (mirror) of the repo
git clone --mirror git@github.com:YOUR_ORG/Health-Tracker-App.git
cd Health-Tracker-App.git

# 2) Run BFG to delete the file
bfg --delete-files backend/.env

# 3) Cleanup and push back
git reflog expire --expire=now --all && git gc --prune=now --aggressive
git push --force
```

Example git-filter-repo flow (more flexible):

```bash
# 1) Install git-filter-repo (follow project instructions)
# 2) Run filter-repo from a fresh clone
git clone --no-local --no-hardlinks git@github.com:YOUR_ORG/Health-Tracker-App.git
cd Health-Tracker-App

git filter-repo --path backend/.env --invert-paths

# 3) Push rewritten history
git push origin --force --all
git push origin --force --tags
```

Safety checklist before rewriting history:
- Inform all collaborators that history will be rewritten.
- Make backups/clones of the repository before proceeding.
- Rotate any secrets immediately (do not wait for history rewrite to finish).
- After rewriting, every collaborator must re-clone or follow the project-specific recovery steps (instructions to rebase/replace local clones).
- Test the rewritten repo in a staging environment before trusting it.

---

## Running in production: systemd and PM2 examples

When deploying, run the web server and worker as separate services. Example systemd unit files and PM2 configuration follow.

### systemd (example)

Create `/etc/systemd/system/health-api.service` for the web server:

```ini
[Unit]
Description=Health Tracker API (web)
After=network.target

[Service]
User=www-data
WorkingDirectory=/srv/health-tracker/backend
Environment=NODE_ENV=production
Environment=PORT=5001
ExecStart=/usr/bin/node src/index.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Create `/etc/systemd/system/health-worker.service` for the scheduler worker:

```ini
[Unit]
Description=Health Tracker Scheduler Worker
After=network.target

[Service]
User=www-data
WorkingDirectory=/srv/health-tracker/backend
Environment=NODE_ENV=production
ExecStart=/usr/bin/node src/worker/scheduler.js
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Commands to enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable health-api.service health-worker.service
sudo systemctl start health-api.service health-worker.service
sudo journalctl -u health-api.service -f
sudo journalctl -u health-worker.service -f
```

### PM2 (example)

Install pm2 and create an ecosystem file `ecosystem.config.js` in the `backend` folder:

```javascript
module.exports = {
	apps: [
		{
			name: 'health-api',
			script: 'src/index.js',
			env: {
				NODE_ENV: 'production',
				PORT: 5001,
			},
			instances: 1,
			autorestart: true,
			watch: false,
		},
		{
			name: 'health-worker',
			script: 'src/worker/scheduler.js',
			env: {
				NODE_ENV: 'production'
			},
			instances: 1,
			autorestart: true,
			watch: false,
		}
	]
};
```

Start with pm2:

```bash
cd backend
npm install -g pm2
pm2 start ecosystem.config.js
pm2 save
pm2 startup
```

## Local dev notes

- Node version: this project assumes Node 18+ (for built-in fetch and modern features). If you run on older Node, install a fetch polyfill (e.g., node-fetch) or upgrade Node.
- Environment: copy `.env` from the project root (if provided) and fill Firebase service account keys and `AI_SERVICE_URL`. Tests under `test/` use `dotenv` to inject env variables.

## Seeding local or emulator data

The project includes a simple seed script at `scripts/seed.js` to create a test user, health profile, a meal and a water log.

Run the seed against your configured Firebase project (be careful: this writes to the project in your `.env`):

```bash
cd backend
npm run seed
```

If you prefer not to touch a real Firebase project, configure the Firebase Emulator and run the seed against the emulator (recommended for local development). See Firebase docs for emulator setup.

### Running seed safely

There are explicit npm scripts to make seeding safer:

- `npm run seed:emulator` — run seed against emulator (sets `USE_FIREBASE_EMULATOR=1`).
- `npm run seed:prod` — run seed against the configured Firebase project, requires confirmation via `CONFIRM_SEED=1` to avoid accidental writes.

Examples:

```bash
# Run against emulator (recommended)
cd backend
npm run seed:emulator

# Run against configured project (dangerous) — requires confirmation
CONFIRM_SEED=1 npm run seed:prod
```

## Register user (example)

To register a new user in Firebase via the backend API (creates Firebase Auth user + Firestore profile):

1. Ensure your `backend/.env` has the Firebase service account values populated (see `.env.example`). If you paste the private key into the env file, escape newlines as `\n`.

2. Start the server in development (disable schedulers):

```bash
cd backend
DISABLE_SCHEDULER=1 npm run dev
```

3. Create a user with curl:

```bash
curl -v -X POST http://127.0.0.1:5001/auth/register \
	-H "Content-Type: application/json" \
	-d '{"fullName":"Test User","email":"you+test@example.com","password":"Password123"}'
```

Response: 201 with user object and JWT cookie set on the response (in development cookie may be http-only). If you see errors about missing env vars, double-check `.env` contents.

If you want to avoid using a real Firebase project during local development, configure the Firebase Emulator and set `USE_FIREBASE_EMULATOR=1` in `.env` before starting the server.


