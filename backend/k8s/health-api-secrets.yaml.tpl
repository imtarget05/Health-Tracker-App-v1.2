apiVersion: v1
kind: Secret
metadata:
  name: health-api-secrets
type: Opaque
stringData:
  # Replace these with actual values or use Kubernetes Secret management
  FIREBASE_PRIVATE_KEY: "${FIREBASE_PRIVATE_KEY}"
  FIREBASE_CLIENT_EMAIL: "${FIREBASE_CLIENT_EMAIL}"
  AI_CHAT_API_KEY: "${AI_CHAT_API_KEY}"
  # add other secrets as needed
