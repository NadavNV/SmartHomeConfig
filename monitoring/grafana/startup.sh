#!/bin/bash
echo "startup.sh started" >&2
set -x
# Set credentials
GRAFANA_URL="http://localhost:3000"
ADMIN_USER="${GF_SECURITY_ADMIN_USER:-admin}"
ADMIN_PASS="${GF_SECURITY_ADMIN_PASSWORD:-admin}"
# Wait until Grafana is up
until curl -s "$GRAFANA_URL/api/health" | grep -q '"database": "ok"'; do
  echo "Waiting for Grafana to start..."
  sleep 3
done

# Set credentials
GRAFANA_URL="http://localhost:3000"
ADMIN_USER="${GF_SECURITY_ADMIN_USER:-admin}"
ADMIN_PASS="${GF_SECURITY_ADMIN_PASSWORD:-admin}"

# Create a viewer user
CREATE_RESPONSE=$(curl -s -X POST "$GRAFANA_URL/api/admin/users" \
  -u "$ADMIN_USER:$ADMIN_PASS" \
  -H "Content-Type: application/json" \
  -d '{
        "name": "Viewer",
        "email": "viewer@example.com",
        "login": "viewer",
        "password": "viewer"
      }')

# Extract the user ID
USER_ID=$(echo "$CREATE_RESPONSE" | grep -oP '"id"\s*:\s*\K\d+')

if [[ -z "$USER_ID" ]]; then
  echo "Failed to create user or extract user ID. Response:"
  echo "$CREATE_RESPONSE"
  exit 1
fi

# Set viewer role
ORG_ID=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" "$GRAFANA_URL/api/user" | jq .orgId)
# USER_ID=$(curl -s -u "$ADMIN_USER:$ADMIN_PASS" "$GRAFANA_URL/api/users/lookup?loginOrEmail=viewer" | jq .id)

ROLE_RESPONSE=$(curl -s -X PATCH "$GRAFANA_URL/api/orgs/$ORG_ID/users/$USER_ID" \
  -H "Content-Type: application/json" \
  -u "$ADMIN_USER:$ADMIN_PASS" \
  -d '{"role": "Viewer"}')

if echo "$ROLE_RESPONSE" | grep -q '"message":"Organization user updated"'; then
  echo "Viewer role successfully assigned."
else
  echo "Failed to assign role. Response:"
  echo "$ROLE_RESPONSE"
  exit 1
fi
