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

## Upgrade recipes

### Patch bump on the current release line (e.g. 8.2.7 → 8.2.8)

Do it on the existing `finter-<major.minor>` branch.

1. `git checkout finter-8.2 && git pull`.
2. Edit `publish.ps1`:
   - `$MongoVersion` → `"8.2.8"` (Docker image tag).
   - `$MongoPackageVersion` → `"8.2.8"` (pinned, from `/8.2` GA channel) **or**
     `"8.2.8~latest"` if pulling from `development`.
3. (Optional) Edit `8.2/Dockerfile` `ENV MONGO_VERSION` to match — this file
   is documentation only, not the build target, but keeping it in sync is
   the project convention.
4. `pwsh ./publish.ps1` to build + push the image.
5. Commit `publish.ps1` (and `8.2/Dockerfile` if touched) with message
   `Update to mongodb 8.2.8`, push branch.
6. Open a version-bump PR in `../youpark.no` (see below).

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
3. Build + smoke test:

   ```bash
   docker build \
     --build-arg MONGO_VERSION=8.3.0~latest \
     --build-arg MONGO_MAJOR=development \
     --build-arg MONGOSH_CHANNEL=8.2 \
     -t mongo-enterprise:8.3.0 ./8.0
   docker run --rm mongo-enterprise:8.3.0 mongod --version
   ```

4. `pwsh ./publish.ps1` to tag + push to `ghcr.io/fintermobilityas/mongo-enterprise:8.3.0`.
5. Commit `publish.ps1` as `Update to mongodb 8.3.0`, push branch.
6. Change GitHub default branch:

   ```bash
   gh api -X PATCH repos/fintermobilityas/mongo -f default_branch=finter-8.3
   ```

7. Open a version-bump PR in `../youpark.no`.

## youpark.no version-bump PR

The mongo version in youpark.no lives in two places plus a helper script.
All three should change in one PR on a branch off `develop`.

- `Directory.Build.props` → `<MongoDBVersion>` property (source of truth;
  `build.ps1` reads this and builds the image URL).
- `docker-compose.yml` → the two `image: ghcr.io/.../mongo-enterprise:X.Y.Z`
  lines.
- `scripts/install-mongodb.sh` → bare-metal installer, supports channel
  selection (stable/development).

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
