param (
    [string]$MongoVersion = "8.0.1"
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$buildPath = Join-Path -Path $scriptPath -ChildPath "8.0"

docker build -t "mongo-enterprise:$MongoVersion" $buildPath
docker tag "mongo-enterprise:$MongoVersion" "ghcr.io/fintermobilityas/mongo-enterprise:$MongoVersion"
docker push "ghcr.io/fintermobilityas/mongo-enterprise:$MongoVersion"
