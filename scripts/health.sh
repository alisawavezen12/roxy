#!/usr/bin/env bash
set -euo pipefail

curl --fail-with-body --silent --show-error --max-time 10 \
  http://localhost:8080/api/health | jq -e '.ok == true and .db == "ok"'
