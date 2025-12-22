#!/usr/bin/env bash
# Dev helper: start AI (uvicorn) and backend (npm) locally.
# Edit paths if you use a different venv or node setup.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AI_DIR="$ROOT/../AI"

echo "Starting AI FastAPI (uvicorn) from: $AI_DIR"
if [ -f "$AI_DIR/.venv311/bin/activate" ]; then
  echo "Activating virtualenv"
  # shellcheck disable=SC1090
  source "$AI_DIR/.venv311/bin/activate"
fi

echo "Run uvicorn in background (port 8000)"
( cd "$AI_DIR" && uvicorn main:app --host 0.0.0.0 --port 8000 --reload ) &
UVICORN_PID=$!

echo "Starting backend"
cd "$ROOT"
if [ -f .env ]; then
  echo "Using .env in backend"
else
  echo "Please copy .env.example -> .env and edit values as needed"
fi
npm install
npm run dev

# When npm run dev exits, kill uvicorn
kill $UVICORN_PID || true
