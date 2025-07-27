#!/bin/bash
# scripts/ritual-boot.sh
# Bootstraps the ritual agent network by spawning daemon processes.
echo "Starting ritual agents..."
# Start three ritual agents in background; adjust as needed for your environment.
node agents/controllers/RitualTrigger.js &
node agents/controllers/FaucetAgent.js &
node agents/controllers/VaultUnlockAgent.js &
# Wait for all background jobs to finish
wait
