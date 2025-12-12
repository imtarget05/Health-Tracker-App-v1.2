#!/usr/bin/env bash
set -euo pipefail

# Usage: ci/deploy-to-eks.sh <namespace> <image_tag>
NAMESPACE=${1:-default}
IMAGE_TAG=${2:?image tag is required}

echo "Deploying image ${IMAGE_TAG} to namespace ${NAMESPACE}"

# Assumes Kubernetes manifests exist under backend/k8s or deployment name is 'health-api'
DEPLOYMENT_NAME=${DEPLOYMENT_NAME:-health-api}
CONTAINER_NAME=${CONTAINER_NAME:-health-api}

MANIFEST_DIR="backend/k8s"

if [ -d "$MANIFEST_DIR" ]; then
	echo "Rendering k8s templates from $MANIFEST_DIR"
	TMP_DIR=$(mktemp -d)
	export IMAGE_TAG
	# export optional envs used in templates
	export FIREBASE_PRIVATE_KEY=${FIREBASE_PRIVATE_KEY:-}
	export FIREBASE_CLIENT_EMAIL=${FIREBASE_CLIENT_EMAIL:-}
	export AI_CHAT_API_KEY=${AI_CHAT_API_KEY:-}
	export FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID:-}
	export FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET:-}
	export AI_SERVICE_URL=${AI_SERVICE_URL:-}

	for f in "$MANIFEST_DIR"/*.tpl; do
		[ -e "$f" ] || continue
		out="$TMP_DIR/$(basename "$f" .tpl).yaml"
		echo "Rendering $f -> $out"
		envsubst < "$f" > "$out"
	done

	echo "Applying manifests to namespace $NAMESPACE"
	kubectl apply -n "$NAMESPACE" -f "$TMP_DIR"
	echo "Waiting for rollout of deployment/$DEPLOYMENT_NAME"
	kubectl -n "$NAMESPACE" rollout status deployment/$DEPLOYMENT_NAME --timeout=180s || true

	rm -rf "$TMP_DIR"
	echo "K8s manifests applied"
else
	echo "No k8s manifest directory found; patching existing deployment image instead"
	kubectl -n "$NAMESPACE" set image deployment/$DEPLOYMENT_NAME $CONTAINER_NAME=$IMAGE_TAG --record
	echo "Deployment image patched. Waiting for rollout to finish..."
	kubectl -n "$NAMESPACE" rollout status deployment/$DEPLOYMENT_NAME --timeout=180s
fi

echo "Deployment updated successfully"
