Kubernetes manifests (templates)
-------------------------------

This folder contains basic template manifests for deploying `health-api` and `health-worker`.

Files ending with `.tpl` are envsubst templates. CI pipeline will render them with `envsubst` and apply.

How to use locally:

1. Prepare environment variables (example):

```bash
export IMAGE_TAG=myregistry/health-api:abcd123
export FIREBASE_PRIVATE_KEY='-----BEGIN PRIVATE KEY-----\n...'
export FIREBASE_CLIENT_EMAIL=service@project.iam.gserviceaccount.com
export AI_CHAT_API_KEY=sk-xxxx
export FIREBASE_PROJECT_ID=your-project-id
export FIREBASE_STORAGE_BUCKET=your-bucket
```

2. Render templates and apply:

```bash
cd backend/k8s
for f in *.tpl; do envsubst < "$f" > "${f%.tpl}.yaml"; done
kubectl apply -f .
```

Security notes:
- Do not store secrets in plaintext in repo. Use sealed-secrets, SOPS, or inject via CI/CD (Kubernetes secrets can be created from CI variables).
- The templates provided are minimal examples — please expand resource requests, liveness/readiness, probes, and RBAC as needed.
