param (
    [string]$MONGO_VERSION = "8.0.1"
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$buildPath = Join-Path -Path $scriptPath -ChildPath "8.0"

docker build -t "mongo-enterprise:$MONGO_VERSION" $buildPath
docker tag "mongo-enterprise:$MONGO_VERSION" "ghcr.io/fintermobilityas/mongo-enterprise:$MONGO_VERSION"
docker push "ghcr.io/fintermobilityas/mongo-enterprise:$MONGO_VERSION"
