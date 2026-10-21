# Finter MongoDB Docker image

This repository publishes `ghcr.io/fintermobilityas/mongo-enterprise:<version>`,
the MongoDB Enterprise image for youpark.no. It keeps only the files of that
image. It started as a fork of `docker-library/mongo` and no longer tracks it.

## What is built

| Path | What it is |
|---|---|
| `image/Dockerfile` | The recipe: Ubuntu noble, the Enterprise packages from `repo.mongodb.com`, the release signing keys |
| `image/docker-entrypoint.sh` | The entrypoint, which the Dockerfile copies |
| `publish.ps1` | The version and the apt channels (its parameter defaults), and the manual publish fallback |
| `.github/workflows/publish.yml` | "Publish image": builds, checks and publishes |

`publish.ps1` builds `./image` with `--build-arg MONGO_VERSION`, `MONGO_MAJOR`
and `MONGOSH_CHANNEL`. The `ARG` defaults in `image/Dockerfile` must be the
same values; "Publish image" checks that.

## Branches

- `main` is the only working branch and the default branch. Each change goes
  to `main`, also a new minor or major line. There is no default-branch switch.
- `master` and the `finter-*` branches are the history of the old layout
  (upstream tracking and one branch for each release line). They stay for
  reference; do not work on them.

## Apt channels (critical: this trips everyone up)

Two MongoDB apt channels are relevant:

| Channel | URL tail | Versions look like | When to use |
|---|---|---|---|
| `development` | `/mongodb-enterprise/development` | `X.Y.Z~latest` (rolling) | Pre-GA (RCs, unreleased majors) |
| `<major.minor>` GA | `/mongodb-enterprise/9.0` etc. | `X.Y.Z` (pinned) | Once that line has GA'd |

`mongodb-enterprise/9.1/` etc. **exist before the line GAs** but only
contain `mongodb-database-tools` until GA. `mongodb-enterprise=9.1.0` will
not install from that channel until MongoDB tags the GA build.

`~` sorts as less-than-empty in dpkg semantics, so
`apt-get install mongodb-enterprise=9.1.0` will **not** match
`9.1.0~latest`. Use the suffixed version explicitly when pulling from
`development`.

## Release signing keys (the other channel trap)

Each major GA series has its own signing key, and `image/Dockerfile` must
import it or apt refuses the channel outright:
`The repository '... mongodb-enterprise/9.0 InRelease' is not signed`.
The Dockerfile imports `server-8.0.asc` (every 8.x GA channel),
`server-9.asc` (every 9.x GA channel) and `server-dev.asc` (the
`development` channel), and exports their fingerprints to
`/etc/apt/keyrings/mongodb.asc`.

The 9.x key is published **major-only** as
`https://pgp.mongodb.com/server-9.asc`
(`B3B42B6C39E5CDDEC0A27E3CF366D55B602E502D`, "MongoDB 9 Release Signing
Key"); `server-9.0.asc` is a 404. Confirm which key signs a channel with:

```bash
curl -fsSL https://repo.mongodb.com/apt/ubuntu/dists/noble/mongodb-enterprise/<channel>/InRelease | gpg --verify
```

A new major (for example 10.0) needs its key: add the download and the
fingerprint to the key block of `image/Dockerfile`, after you confirm them
with the command above.

## Release discovery and package gate

For an update request that does not name a version, check the tracked release
line's official release notes first (currently [MongoDB 9.0](https://www.mongodb.com/docs/manual/release-notes/9.0/)).
The newest patch listed there is the latest officially released target, even
when the Enterprise apt feed has not caught up.

Release discovery and package availability are separate facts: release notes
establish what MongoDB has released, while the exact Enterprise apt package
establishes whether this image can be built. If the target is absent from the
GA feed and no exact development package has been explicitly approved, stop
before creating branches, images, or file changes and report the feed lag.

## Update the image (GA patch, minor or major)

The same steps for each kind of release.

1. Fetch `origin/main` and create a separate worktree on a new branch from
   its exact commit. Never update from a shared checkout or a cached
   remote-tracking ref.
2. Edit the defaults of `publish.ps1`:
   - `$MongoVersion` (the image tag) and `$MongoPackageVersion` (the apt
     version): `"X.Y.Z"`.
   - `$MongoAptChannel` and `$MongoMongoshChannel`: `"X.Y"`. They change
     only for a new minor or major line.
3. Edit the `ARG MONGO_VERSION`, `ARG MONGO_MAJOR` and `ARG MONGOSH_CHANNEL`
   defaults of `image/Dockerfile` to the same values. For a new major, add
   its signing key (see above).
4. Commit `publish.ps1` and `image/Dockerfile` as `Update to mongodb X.Y.Z`
   and open a pull request into `main`. "Publish image" builds and checks the
   image as a dry run on the pull request; it must pass.
5. Merge the pull request. The push to `main` starts "Publish image", which
   builds, checks and publishes the tag from the merged commit.
6. Read the manifest digest and provenance revision from that run and check
   them against the merge commit.
7. Open a version-bump PR in `../youpark.no` (see below).

A pre-GA build from the `development` channel (`X.Y.Z~latest` or
`X.Y.Z~<githash>`, `$MongoAptChannel = "development"`, and
`$MongoMongoshChannel` the last GA channel that has `mongodb-mongosh`) needs
a person's approval first. A pre-GA build holds the tag of its GA version,
and the workflow never overwrites a published tag, so the GA build then needs
a person too.

To build and smoke test by hand:

```bash
docker build \
  --build-arg MONGO_VERSION=9.0.4 \
  --build-arg MONGO_MAJOR=9.0 \
  --build-arg MONGOSH_CHANNEL=9.0 \
  -t mongo-enterprise:9.0.4 ./image
docker run --rm -e GLIBC_TUNABLES=glibc.pthread.rseq=1 mongo-enterprise:9.0.4 mongod --version
```

## Publishing through the workflow

`.github/workflows/publish.yml` ("Publish image") publishes the image. A push
to `main` that changes `publish.ps1` or a file in `image/` starts it. It
builds `./image` once with the parameter defaults of `publish.ps1` and pushes
that image without a tag, checks the Enterprise package inventory,
`mongod --version` and the provenance revision of that exact image, and only
then tags its digest `ghcr.io/fintermobilityas/mongo-enterprise:<MongoVersion>`,
with the job's token. It prints `Published <image>:<tag>@<digest>` plus the
provenance revision. A run that fails a check leaves an untagged version in
the package.

- It never overwrites a published tag and never creates a package. When the
  tag exists and the push did not change `$MongoVersion` (for example a change
  of the entrypoint only), there is nothing to publish: the run ends green
  with the notice "Nothing to publish". When the push changed the version to
  one whose tag exists, the run fails.
- Pull requests that change `publish.ps1`, `image/` or the workflow get a dry
  run: the same build and checks, with nothing pushed.
- Dry run by hand: `gh workflow run publish.yml -R fintermobilityas/mongo --ref main -f push=false`.
- Publish again after a failed or cancelled run: the same with `-f push=true`.
  Publishing runs wait for each other, so two runs never check and push the
  same tag at once.

The package is private and linked to `fintermobilityas/youpark.no`. Never
change its visibility or its repository link. Its **Manage Actions access**
gives this repository the Write role; that setting exists only in the
package's web settings.

`pwsh ./publish.ps1` from a machine with Docker and a ghcr login (see
Pre-flight checks) stays the manual fallback for a person.

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

## Claude review

Claude reviews every pull request through `.github/workflows/claude-review.yml`, with at most 2 rounds per PR. Never request Copilot or another bot reviewer. This rule replaces the Copilot reviewer steps in the shared company procedure for this repository.

- Round 1 runs automatically when a ready PR from a branch of this repository opens. A pull request from a fork gets a review only after a maintainer has examined its diff and added the `claude-review` label. Its summary comment ends with `<!-- claude-review head=<sha> findings=<n> -->` and covers only that head.
- Fix or answer every finding on the same PR and push. Wait until `gh api repos/fintermobilityas/mongo/pulls/<n> -q .head.sha` shows the new head, then add the `claude-review` label (`gh pr edit <n> --add-label claude-review`). That runs round 2, and the job removes the label when it finishes.
- Do not request a third round. After round 2, fix or answer every finding; the PR then merges on green CI.
- `.github/review-instructions.md` sets what the review reports. Put review rules there, not in a reviewer-specific file.

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
   `gh api repos/<owner>/<repo>/issues/<n>/comments` (issue-level); do not
   rely on `.../pulls/<n>/reviews` alone, it only lists review events. Verify
   each new comment against the code; if valid, fix, push, reply to the thread
   with the commit hash, then resolve the thread with the `resolveReviewThread`
   mutation. If invalid, reply with evidence and leave it open unless the user
   pre-approved closing.
3. **Polling**: check CI and threads together every ~30 s in one loop with an
   explicit timeout (~60 min budget). A push resets CI; re-evaluate from the
   new head commit.
4. **Merge gate**: only when the head commit is CI-green, has zero unresolved
   threads, and `mergeStateStatus` is CLEAN, run `gh pr merge <n> --squash`
   and report the merge commit.

## Pre-flight checks

For publishing through the workflow, only `gh auth status` applies. The rest
is for the manual `pwsh ./publish.ps1` fallback.

- `docker info`: daemon running.
- `docker login ghcr.io`: check `~/.docker/config.json` has `ghcr.io`.
- `gh auth status`: need `repo`.
- `which pwsh`: needed for `publish.ps1`.

## Gotchas

- `publish.ps1` hardcodes `$buildPath = "image"`. Don't add or rename build
  directories expecting `publish.ps1` to find them.
- This repository has none of the upstream docker-library files: no
  templates, no `versions.json`, no other version folders, and no "GitHub CI"
  or "Verify Templating" workflow. "Publish image" builds and checks the one
  image that it ships. Do not merge `docker-library/mongo` into `main`.
- `mongodb-enterprise-cryptd` resolves to the highest version in the chosen
  apt channel, which can be higher than the other packages (e.g. `9.0.0~latest`
  while the rest are `8.3.0~latest`). That's how MongoDB publishes it;
  nothing to fix.
