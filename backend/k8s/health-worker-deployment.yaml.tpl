apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-worker
  labels:
    app: health-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: health-worker
  template:
    metadata:
      labels:
        app: health-worker
    spec:
      containers:
        - name: health-worker
          image: ${WORKER_IMAGE_TAG:-${IMAGE_TAG}}
          imagePullPolicy: IfNotPresent
          command: ["node", "src/worker/scheduler.js"]
          envFrom:
            - secretRef:
                name: health-api-secrets
            - configMapRef:
                name: health-api-config
