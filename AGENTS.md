# Finter MongoDB Docker — version upgrade playbook

This fork of `docker-library/mongo` publishes
`ghcr.io/fintermobilityas/mongo-enterprise:<version>` for youpark.no.

## What's actually built

`publish.ps1` builds **`./8.0/Dockerfile`** regardless of the version being
released. The directory name is historical — it is the Finter-customized
Dockerfile (enterprise package, PGP keys, etc.). Everything passed through
`--build-arg` overrides the defaults inside that Dockerfile.

The `8.2/`, `8.3-rc/` etc. directories on master are regenerated from
`mongo-vendor` upstream templates and are **not** used by the build.

## Branch layout

- `master` — tracks `mongo-vendor/master` (upstream `docker-library/mongo`).
- `finter-<major.minor>` — per-release-line branches. The GitHub default
  branch points at the currently-shipping one. A new major/minor bump gets a
  new branch; patch bumps go on the existing one.
- Default branch for `fintermobilityas/mongo` is set via
  `gh api -X PATCH repos/fintermobilityas/mongo -f default_branch=<branch>`.

## Apt channels (critical — trips everyone up)

Two MongoDB apt channels are relevant:

| Channel | URL tail | Versions look like | When to use |
|---|---|---|---|
| `development` | `/mongodb-enterprise/development` | `X.Y.Z~latest` (rolling) | Pre-GA (RCs, unreleased majors) |
| `<major.minor>` GA | `/mongodb-enterprise/8.2` etc. | `X.Y.Z` (pinned) | Once that line has GA'd |

`mongodb-enterprise/8.3/` etc. **exist before the line GAs** but only
contain `mongodb-database-tools` until GA. `mongodb-enterprise=8.3.0` will
not install from that channel until MongoDB tags the GA build.

`~` sorts as less-than-empty in dpkg semantics, so
`apt-get install mongodb-enterprise=8.3.0` will **not** match
`8.3.0~latest`. Use the suffixed version explicitly when pulling from
`development`.

## Release discovery and package gate

For an update request that does not name a version, check the tracked release
line's official release notes first (currently [MongoDB 8.3](https://www.mongodb.com/docs/manual/release-notes/8.3/)).
The newest patch listed there is the latest officially released target, even
when the Enterprise apt feed has not caught up.

Release discovery and package availability are separate facts: release notes
establish what MongoDB has released, while the exact Enterprise apt package
establishes whether this image can be built. If the target is absent from the
GA feed and no exact development package has been explicitly approved, stop
before creating branches, images, or file changes and report the feed lag.

Always commit and push the exact Dockerfile and `publish.ps1` source before
publishing the image. After publication, verify that the manifest provenance
records that committed revision.

## Upgrade recipes

### Patch bump on the current release line (e.g. 8.2.7 → 8.2.8)

Do it on the existing `finter-<major.minor>` branch.

1. Fetch `origin/finter-8.2` and create a separate worktree from its exact
   commit. Never update from a shared checkout or a cached remote-tracking ref.
2. Edit `publish.ps1`:
   - `$MongoVersion` → `"8.2.8"` (Docker image tag).
   - `$MongoPackageVersion` → `"8.2.8"` (pinned, from `/8.2` GA channel) **or**
     `"8.2.8~latest"` if pulling from `development`.
3. Edit `8.0/Dockerfile` `ARG MONGO_VERSION` to match.
4. Commit `publish.ps1` and `8.0/Dockerfile` as
   `Update to mongodb 8.2.8`, then push the commit to `finter-8.2`.
5. From that clean committed source, run `pwsh ./publish.ps1` to build and push
   the image.
6. Verify the image version, Enterprise package inventory, manifest digest,
   and manifest provenance against the pushed source commit.
7. Open a version-bump PR in `../youpark.no` (see below).

### Minor/major bump (e.g. 8.2 → 8.3)

New release line. Create a new branch.

1. `git fetch origin && git checkout -b finter-8.3 origin/finter-8.2`.
2. Edit `publish.ps1`:
   - `$MongoVersion` = `"8.3.0"` (image tag).
   - `$MongoPackageVersion` = `"8.3.0~latest"` until 8.3 GA's, then switch
     to `"8.3.0"` + channel `"8.3"`.
   - `$MongoAptChannel` = `"development"` pre-GA, `"8.3"` post-GA.
   - `$MongoMongoshChannel` = last GA channel that has `mongodb-mongosh`
     (`"8.2"` while 8.3 is pre-GA — the `/8.3` channel only has
     `mongodb-database-tools` until GA). Switch to `"8.3"` once mongosh
     lands there.
3. Commit the image source and push the new `finter-8.3` branch.
4. Build + smoke test from that clean committed source:

   ```bash
   docker build \
     --build-arg MONGO_VERSION=8.3.0~latest \
     --build-arg MONGO_MAJOR=development \
     --build-arg MONGOSH_CHANNEL=8.2 \
     -t mongo-enterprise:8.3.0 ./8.0
   docker run --rm mongo-enterprise:8.3.0 mongod --version
   ```

5. `pwsh ./publish.ps1` to tag + push to `ghcr.io/fintermobilityas/mongo-enterprise:8.3.0`.
6. Verify the manifest digest and provenance against the pushed source commit.
7. Change GitHub default branch:

   ```bash
   gh api -X PATCH repos/fintermobilityas/mongo -f default_branch=finter-8.3
   ```

8. Open a version-bump PR in `../youpark.no`.

## youpark.no version-bump PR

The MongoDB version and immutable image digest in youpark.no live in shared
properties, Compose references, and a helper script. Update them together in
one PR on a branch off `develop`.

- `Directory.Build.props` → `<MongoDBVersion>` and `<MongoDBImageDigest>`.
- `docker-compose.yml` → both
  `image: ghcr.io/.../mongo-enterprise:X.Y.Z@sha256:<digest>` references.
- `scripts/install-mongodb.sh` → bare-metal installer, supports channel
  selection (stable/development).
- `scripts/verify-mongodb-image-pins.sh` → run it to verify the shared pins.

## PR Review, Monitoring & Merge

When a PR is due to merge (e.g. the youpark.no version-bump PR) and the user
explicitly authorizes the merge in the request (e.g. "monitor CI and merge when
green"), run this loop in the PR's worktree:

1. **CI gate**: `gh pr checks <n> --json name,state,bucket`. Green = no `pending`
   bucket and every other bucket `pass` or `skipping`; `fail`/`cancel` → fix on
   the branch and restart the loop.
2. **Feedback gate**: poll unresolved review threads (GraphQL
   `reviewThreads { id isResolved }`) plus new comments via
   `gh api repos/<owner>/<repo>/pulls/<n>/comments` (inline) and
   `gh api repos/<owner>/<repo>/issues/<n>/comments` (issue-level) — do not
   rely on `.../pulls/<n>/reviews` alone, it only lists review events. Verify
   each new comment against the code; if valid, fix, push, reply to the thread
   with the commit hash, then resolve the thread with the `resolveReviewThread`
   mutation. If invalid, reply with evidence and leave it open unless the user
   pre-approved closing.
3. **Polling**: check CI and threads together every ~30 s in one loop with an
   explicit timeout (~60 min budget). A push resets CI — re-evaluate from the
   new head commit.
4. **Merge gate**: only when the head commit is CI-green, has zero unresolved
   threads, and `mergeStateStatus` is CLEAN, run `gh pr merge <n> --squash`
   and report the merge commit.

## Pre-flight checks

- `docker info` — daemon running.
- `docker login ghcr.io` — check `~/.docker/config.json` has `ghcr.io`.
- `gh auth status` — need `repo` and ideally `admin:org` for default-branch
  changes.
- `which pwsh` — needed for `publish.ps1`.

## Gotchas

- `publish.ps1` hardcodes `$buildPath = "8.0"`. Don't add or rename build
  directories expecting `publish.ps1` to find them.
- `mongodb-enterprise-cryptd` resolves to the highest version in the chosen
  apt channel, which can be higher than the other packages (e.g. `9.0.0~latest`
  while the rest are `8.3.0~latest`). That's how MongoDB publishes it;
  nothing to fix.
- The `8.3-rc/` and `8.2/` directories on this repo are upstream-regenerated
  from `mongo-vendor` templates via `update.sh`. They drift from what we
  actually ship; don't treat them as the source of truth.
