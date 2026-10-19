# mongo-enterprise image

This repository builds and publishes `ghcr.io/fintermobilityas/mongo-enterprise:<version>`, a MongoDB Enterprise image on Ubuntu. The package is private.

- `image/` holds the Dockerfile and the entrypoint.
- `publish.ps1` holds the version and the apt channels.
- The "Publish image" workflow builds and checks the image on each pull request, and publishes the version tag when a change reaches `main`.

To publish a new MongoDB release, change the version in `publish.ps1` and `image/Dockerfile` in a pull request into `main`, and merge it after its dry run passes. [AGENTS.md](AGENTS.md) has the full steps.

The image started from [docker-library/mongo](https://github.com/docker-library/mongo) (see [LICENSE](LICENSE)).
