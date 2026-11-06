#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"

echo -e "\nDeploying floci-aws-emulator service...\n"
docker compose --progress auto up --detach --build

until curl -s http://localhost:4566/_floci/health >/dev/null 2>&1; do
  echo -e "\nWaiting for floci-aws-emulator to be ready...\n"
  sleep 10
done

echo -e "\nFloci-aws-emulator is now running at http://localhost:4566\n"