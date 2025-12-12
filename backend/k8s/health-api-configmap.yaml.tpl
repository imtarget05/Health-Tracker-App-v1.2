apiVersion: v1
kind: ConfigMap
metadata:
  name: health-api-config
data:
  NODE_ENV: "production"
  PORT: "5001"
  FIREBASE_PROJECT_ID: "${FIREBASE_PROJECT_ID}"
  FIREBASE_STORAGE_BUCKET: "${FIREBASE_STORAGE_BUCKET}"
  AI_SERVICE_URL: "${AI_SERVICE_URL}"
