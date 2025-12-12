apiVersion: apps/v1
kind: Deployment
metadata:
  name: health-api
  labels:
    app: health-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: health-api
  template:
    metadata:
      labels:
        app: health-api
    spec:
      containers:
        - name: health-api
          image: ${IMAGE_TAG}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 5001
          envFrom:
            - secretRef:
                name: health-api-secrets
            - configMapRef:
                name: health-api-config
          livenessProbe:
            httpGet:
              path: /api/health
              port: 5001
            initialDelaySeconds: 20
            periodSeconds: 15
          readinessProbe:
            httpGet:
              path: /api/health
              port: 5001
            initialDelaySeconds: 10
            periodSeconds: 10
