#!/bin/sh
set -eu

./scripts/sync_css.sh src assets
exec gleam run -m lustre/dev start
