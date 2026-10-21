# Review instructions

The Claude review workflow (`.github/workflows/claude-review.yml`) reads this file from the base branch. It sets what a review reports. `AGENTS.md` holds the full repository rules.

Report a finding only for one of these:

- a concrete input or state and the wrong result it causes: a bug, an image that fails to build or start, a wrong MongoDB version or channel, an overwritten or wrongly tagged image, a security hole, or a broken contract with youpark.no;
- an item that `AGENTS.md` or this file requires for the kind of change, and that the pull request does not have.

Do not report style, naming, formatting, comment wording, or a choice between two correct designs.

## What to check in this repository

- **Version parity.** The `publish.ps1` parameter defaults and the `ARG MONGO_VERSION`, `ARG MONGO_MAJOR` and `ARG MONGOSH_CHANNEL` defaults in `image/Dockerfile` are the same values.
- **Apt channels.** A GA version installed from its `<major.minor>` channel, and a `development` build that uses the suffixed `X.Y.Z~latest` version and names the person's approval in the pull request.
- **Signing keys.** A new major line adds its release key download and fingerprint to the key block of `image/Dockerfile`. Never disable apt signature checks.
- **Publish workflow.** "Publish image" never overwrites a published tag, never creates or relinks the package, never changes its visibility, and tags only a digest that passed the package, `mongod --version` and provenance checks. Pull requests get a dry run that pushes nothing.
- **Pull request scope.** Changes go to `main` only. No upstream `docker-library/mongo` files, templates or other version folders come back.
- **Secrets.** Registry tokens or other credentials in the Dockerfile, scripts, workflow or the pull request text.
