#!/bin/bash
set -e

# Configuration
DOMAIN=$1
ADMIN_PASSWORD=${2:-"admin"}

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain> [admin_password]"
    exit 1
fi

KEYCLOAK_URL="https://keycloak.$DOMAIN"

echo "[INFO] Fixing Keycloak Client Configuration for domain: $DOMAIN"

# 1. Get Admin Token
echo "[INFO] Getting Admin Token..."
TOKEN_RESPONSE=$(curl -k -s -X POST "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
    -d "client_id=admin-cli" \
    -d "username=admin" \
    -d "password=$ADMIN_PASSWORD" \
    -d "grant_type=password")

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
    echo "[ERROR] Failed to get admin token. Response: $TOKEN_RESPONSE"
    exit 1
fi

# 2. Get Client UUID
echo "[INFO] Getting Client UUID for iot-load-tester..."
CLIENTS_RESPONSE=$(curl -k -s -X GET "$KEYCLOAK_URL/admin/realms/iot/clients?clientId=iot-load-tester" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

CLIENT_UUID=$(echo "$CLIENTS_RESPONSE" | jq -r '.[0].id')

if [ -z "$CLIENT_UUID" ] || [ "$CLIENT_UUID" == "null" ]; then
    echo "[ERROR] Failed to find Client UUID. Response: $CLIENTS_RESPONSE"
    exit 1
fi

echo "[INFO] Found Client UUID: $CLIENT_UUID"

# 3. Update Client
# We construct the update JSON manually to avoid complex jq filtering issues with variables
# strict HTTPS redirects + localhost for port-forwarding
REDIRECT_URIS="[\"https://auth.$DOMAIN/*\", \"https://loadtest.$DOMAIN/*\", \"http://localhost:8090/*\"]"
WEB_ORIGINS="[\"*\"]"

# Using a partial update (PATCH would be nice but Keycloak Admin API uses PUT for full updates usually)
# However, we can fetch the existing rep and modify it, OR just rely on the fact that we only really care about these fields.
# But to be safe, let's just PUT with the modified representation we got from GET.

# Use jq to robustly update the JSON object
NEW_CLIENT_REP=$(echo "$CLIENTS_RESPONSE" | jq -r --argjson ruris "$REDIRECT_URIS" --argjson origins "$WEB_ORIGINS" '.[0] | .redirectUris = $ruris | .webOrigins = $origins')

echo "[INFO] Updating Client Config..."
UPDATE_RESPONSE=$(curl -k -s -o /dev/null -w "%{http_code}" -X PUT "$KEYCLOAK_URL/admin/realms/iot/clients/$CLIENT_UUID" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$NEW_CLIENT_REP")

if [[ "$UPDATE_RESPONSE" =~ 2.. ]]; then
    echo "[SUCCESS] Keycloak Client configured successfully."
else
    echo "[ERROR] Failed to update client. HTTP Code: $UPDATE_RESPONSE"
    exit 1
fi
