param (
    [string]$MongoVersion = "9.0.0",
    [string]$MongoPackageVersion = "9.0.0~556d280e",
    [string]$MongoAptChannel = "development",
    [string]$MongoMongoshChannel = "8.3"
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$buildPath = Join-Path -Path $scriptPath -ChildPath "8.0"

$buildArgs = @()

if ($MongoPackageVersion) {
    $buildArgs += "--build-arg"
    $buildArgs += "MONGO_VERSION=$MongoPackageVersion"
}

if ($MongoAptChannel) {
    $buildArgs += "--build-arg"
    $buildArgs += "MONGO_MAJOR=$MongoAptChannel"
}

if ($MongoMongoshChannel) {
    $buildArgs += "--build-arg"
    $buildArgs += "MONGOSH_CHANNEL=$MongoMongoshChannel"
}

$ErrorActionPreference = "Stop"

# Native commands do not throw on failure; check $LASTEXITCODE after each docker
# call so a failed build/tag/push aborts the script with a non-zero exit code
# (a denied push used to be silently swallowed and the script exited 0).
docker build @buildArgs -t "mongo-enterprise:$MongoVersion" $buildPath
if ($LASTEXITCODE -ne 0) { throw "docker build failed with exit code $LASTEXITCODE" }

docker tag "mongo-enterprise:$MongoVersion" "ghcr.io/fintermobilityas/mongo-enterprise:$MongoVersion"
if ($LASTEXITCODE -ne 0) { throw "docker tag failed with exit code $LASTEXITCODE" }

docker push "ghcr.io/fintermobilityas/mongo-enterprise:$MongoVersion"
if ($LASTEXITCODE -ne 0) { throw "docker push failed with exit code $LASTEXITCODE (is the ghcr.io login token missing the write:packages scope?)" }
