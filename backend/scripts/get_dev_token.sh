#!/usr/bin/env bash
# Dev helper: create a test user (or use existing) and print backend JWT returned by POST /auth/register
# WARNING: This is a dev helper. Do NOT use in production.

set -euo pipefail

BACKEND_BASE=${BACKEND_BASE:-http://127.0.0.1:5001}

# Support quiet mode: ./get_dev_token.sh -q or --quiet to print token only
QUIET=0
if [ "$1" = "-q" ] || [ "$1" = "--quiet" ]; then
  QUIET=1
  # shift args so positional params still work
  shift
fi

EMAIL=${1:-tester+dev@example.com}
PASSWORD=${2:-password123}
FULLNAME=${3:-Dev Tester}

if [ "$QUIET" -eq 0 ]; then
  echo "Using backend: $BACKEND_BASE"
  echo "Creating or using user: $EMAIL"
fi

resp=$(curl -s -X POST "$BACKEND_BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"fullName\": \"$FULLNAME\", \"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}")

# Use HTTP code to decide; capture body and code together
resp_and_code=$(curl -s -w "\n%{http_code}" -X POST "$BACKEND_BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"fullName\": \"$FULLNAME\", \"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}")

http_code=$(printf "%s" "$resp_and_code" | tail -n1)
body=$(printf "%s" "$resp_and_code" | sed '$d')

# If registration failed because email exists, try login-email endpoint
if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
  if printf "%s" "$body" | grep -qi "Email already exists"; then
    if [ "$QUIET" -eq 0 ]; then
      echo "Email already exists — attempting login with email/password"
    fi
    resp_and_code=$(curl -s -w "\n%{http_code}" -X POST "$BACKEND_BASE/auth/login-email" \
      -H "Content-Type: application/json" \
      -d "{\"email\": \"$EMAIL\", \"password\": \"$PASSWORD\"}")
    http_code=$(printf "%s" "$resp_and_code" | tail -n1)
    body=$(printf "%s" "$resp_and_code" | sed '$d')
  fi
fi

# Parse token from body using jq if available, otherwise python
token=""
if command -v jq >/dev/null 2>&1; then
  token=$(printf "%s" "$body" | jq -r '.token // empty' 2>/dev/null || true)
else
  token=$(printf "%s" "$body" | python3 -c 'import sys,json
try:
    data=json.load(sys.stdin)
    print(data.get("token",""))
except Exception:
    sys.exit(0)')
fi

if [ -n "$token" ]; then
  if [ "$QUIET" -eq 1 ]; then
    # print token only
    printf "%s" "$token"
  else
    echo "\nBackend JWT (use this as Authorization: Bearer <token>):\n$token"
  fi
else
  if [ "$QUIET" -eq 0 ]; then
    echo "Failed to obtain token. Server response (http_code=$http_code):" >&2
    echo "$body" >&2
  else
    # print body to stderr for debugging in quiet mode
    echo "$body" >&2
  fi
  exit 1
fi
