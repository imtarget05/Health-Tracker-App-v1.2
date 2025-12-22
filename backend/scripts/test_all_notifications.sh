#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
API_URL="http://localhost:5001"

echo "Starting E2E notification test against $API_URL"

# 1) Register a test user
echo "Registering test user..."
REGISTER_RESP=$(curl -s -X POST "$API_URL/auth/register" -H 'Content-Type: application/json' -d '{"email":"e2e.test+notif@example.com","password":"Password123!","displayName":"E2E Notif"}')
echo "Register response: $REGISTER_RESP"

# Extract USER_ID from register response early so we can attach a device token correctly
USER_ID=$(echo "$REGISTER_RESP" | sed -n 's/.*"uid":"\([^"]*\)".*/\1/p')
if [ -z "$USER_ID" ]; then
  echo "User ID not found in register response; will try to obtain it later from /auth/me if needed"
fi

# 2) Login via email endpoint to get BE JWT
echo "Logging in to get token..."
LOGIN_RESP=$(curl -s -X POST "$API_URL/auth/login-email" -H 'Content-Type: application/json' -d '{"email":"e2e.test+notif@example.com","password":"Password123!"}')
JWT=$(echo "$LOGIN_RESP" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
if [ -z "$JWT" ]; then
  echo "Failed to get JWT from login response:" >&2
  echo "$LOGIN_RESP" >&2
  exit 1
fi
echo "Obtained JWT"

# 3) Add a device token (dev helper script) if FCM_TOKEN env provided
if [ -n "${FCM_TOKEN-}" ]; then
  # Ensure we have the UID to associate with the token. Fall back to /auth/me using the JWT.
  if [ -z "${USER_ID-}" ]; then
    USER_ID=$(curl -s -X GET "$API_URL/auth/me" -H "Authorization: Bearer $JWT" | sed -n 's/.*"uid":"\([^"]*\)".*/\1/p')
  fi

  if [ -z "$USER_ID" ]; then
    echo "Cannot determine user id to attach device token; skipping token add" >&2
  else
    echo "Adding device token via helper script..."
    # call the helper with positional args: <userId> <deviceToken>
    node "$ROOT/scripts/add_test_device_token.js" "$USER_ID" "$FCM_TOKEN"
  fi
else
  echo "No FCM_TOKEN provided; will still write notification records to DB but won't send push";
fi

# Note: There is no direct POST /meals endpoint in this backend (meals are created from AI detection).
# We'll skip meal creation in this E2E script and focus on water/workout notifications.

# 5) Log water intake
echo "Logging water intake..."
WATER_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
WATER_BODY=$(printf '{"amountMl":250,"time":"%s"}' "$WATER_TIME")
curl -s -X POST "$API_URL/water" -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' -d "$WATER_BODY" | jq -C .

# 6) Create a workout to trigger workout complete notification
echo "Creating workout..."
WORKOUT_BODY=$(printf '{"type":"run","duration":30,"caloriesBurned":300}')
curl -s -X POST "$API_URL/workouts" -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' -d "$WORKOUT_BODY" | jq -C .

# 7) Manually invoke daily summary emit (dev-only endpoint) if available
echo "Emitting daily summary (dev endpoint)..."
curl -s -X POST "$API_URL/notifications/emit" -H "Authorization: Bearer $JWT" -H 'Content-Type: application/json' -d '{"type":"DAILY_SUMMARY"}' | jq -C . || true

# 8) Wait briefly for scheduler handlers
echo "Waiting 3s for background tasks..."
sleep 3

# 9) Fetch notifications for the user
echo "Fetching notifications for user..."
USER_ID=$(echo "$REGISTER_RESP" | sed -n 's/.*"uid":"\([^"]*\)".*/\1/p')
if [ -z "$USER_ID" ]; then
  echo "User ID not found in register response; trying /auth/me"
  USER_ID=$(curl -s -X GET "$API_URL/auth/me" -H "Authorization: Bearer $JWT" | sed -n 's/.*"uid":"\([^"]*\)".*/\1/p')
fi
echo "User ID: $USER_ID"

# Query notifications collection via admin endpoint if available
echo "Listing notifications via admin/dev endpoint..."
curl -s -X GET "$API_URL/notifications/user/$USER_ID" -H "Authorization: Bearer $JWT" | jq -C . || true

echo "E2E notification test completed"
