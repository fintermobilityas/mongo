param (
    [string]$MongoVersion = "8.3.3",
    [string]$MongoPackageVersion = "8.3.3",
    [string]$MongoAptChannel = "8.3",
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

docker build @buildArgs -t "mongo-enterprise:$MongoVersion" $buildPath
docker tag "mongo-enterprise:$MongoVersion" "ghcr.io/fintermobilityas/mongo-enterprise:$MongoVersion"
docker push "ghcr.io/fintermobilityas/mongo-enterprise:$MongoVersion"
