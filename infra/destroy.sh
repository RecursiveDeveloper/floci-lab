#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

echo -e "\nDestroying containers, networks, images and volumes\n"

# Kill containers floci spins up and also removes the anonymous volumes
docker ps -aq --filter "name=floci-aws" | xargs -r docker rm -f -v
docker compose down --remove-orphans --rmi all --volumes

# Remove images floci pulls at runtime for its emulated services
docker images -q \
  --filter "reference=floci/floci-ui*" \
  --filter "reference=rancher/k3s*" \
  --filter "reference=registry:2" | xargs -r docker rmi -f || true

# Remove volumes holding state created by floci
docker volume ls -q --filter "name=floci-aws" | xargs -r docker volume rm

# Remove networks created by floci
docker network ls -q --filter "name=floci-aws" | xargs -r docker network rm

if [ -d "./data" ]; then
  echo -e "\nRemoving local data\n"
  sudo rm -rf ./data
fi
