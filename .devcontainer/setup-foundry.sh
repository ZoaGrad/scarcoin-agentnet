#!/usr/bin/env bash
set -euo pipefail
if command -v forge >/dev/null 2>&1; then exit 0; fi
curl -L https://foundry.paradigm.xyz | bash
/root/.foundry/bin/foundryup
echo 'Foundry installed'
