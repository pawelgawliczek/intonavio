# Intonavio — Development Workflow

## Git & GitHub Conventions

### Repository

- Remote: GitHub (`github.com/pawelgawliczek/intonavio`)
- Default branch: `main` — squash merge only, auto-delete branches on merge. Branch protection rules (required CI checks) pending GitHub Pro upgrade for private repos.
- Branch naming: `feat/description`, `fix/description`, `spike/description`

### Commits

- Imperative mood, concise. `Add stem download endpoint`, not `Added` or `Adding`.
- One logical change per commit. Don't mix refactoring with feature work.

### Pull Requests

- All changes go through PRs — no direct pushes to `main`.
- PR descriptions must include what changed and how to test it.
- Require passing CI (lint + test) before merge.
- Squash merge to `main` for clean history.

### GitHub Issues & Projects

- Use GitHub Issues for all task tracking (features, bugs, spikes).
- Label issues: `feature`, `bug`, `spike`, `chore`, `docs`.
- Use GitHub Projects board with columns: Backlog → In Progress → Review → Done.
- Reference issues in commits and PRs: `Fixes #123`, `Part of #45`.

## CI/CD (GitHub Actions)

For deployment infrastructure details, see `docs/08-infrastructure.md`.

### CI workflow (`ci.yml`) — runs on every PR

1. Install dependencies (`pnpm install`)
2. Lint all packages (`pnpm lint`)
3. Run unit + integration tests (`pnpm test`)
4. Check test coverage thresholds
5. Build all packages (`pnpm build`)
6. Build Docker images (verify they build)

### Deploy workflow (`deploy.yml`) — runs on merge to `main`

Currently builds API and worker (web not yet implemented):

1. Build Docker images for `api` and `worker`, push to GitHub Container Registry (ghcr.io)
2. SSH into production server
3. Pull latest images and restart containers
4. Run database migrations (`prisma migrate deploy`)
5. Health check verification (`GET /v1/health`)
6. Verify worker heartbeat in logs

Note: GHCR auth on the server requires a PAT with `read:packages` scope.

### Backup workflow (`backup.yml`) — scheduled daily

1. `pg_dump` PostgreSQL to compressed file
2. Upload to Cloudflare R2 backup bucket
3. Retain last 30 backups, delete older
