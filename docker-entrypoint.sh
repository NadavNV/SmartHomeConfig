#!/bin/bash

# Fix docker.sock permissions if needed
if [ -S /var/run/docker.sock ]; then
    chown root:docker /var/run/docker.sock
    chmod 660 /var/run/docker.sock
fi

# Start Jenkins
exec /usr/bin/tini -- /usr/local/bin/jenkins.sh