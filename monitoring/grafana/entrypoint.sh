#!/bin/bash
set -e

# Start run.sh in background and log output
/run.sh >> /proc/1/fd/1 2>&1 &

# Run startup.sh in foreground so we see its logs
echo "Running startup.sh" >> /proc/1/fd/1
/startup.sh >> /proc/1/fd/1 2>&1

# Wait for background job to finish
wait
