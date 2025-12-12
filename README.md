# Health-Tracker-App
Health Tracker App helps you monitor your daily health and build healthy habits. Track your steps, calories, heart rate, and sleep, get reminders for exercise or medications, and keep an eye on your mood and mental well-being.

## CI/CD (GitLab) overview

This repo includes a sample GitLab CI configuration (`.gitlab-ci.yml`) that implements a pipeline inspired by the provided diagram:

- Stages: prepare -> test -> semgrep -> sonar -> docker build & push -> deploy
- The pipeline expects several CI variables to be configured in GitLab project settings (see list below).

Required CI variables (examples):
- `CI_REGISTRY`, `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD` — Docker registry credentials
- `SONAR_HOST_URL`, `SONAR_TOKEN`, `SONAR_PROJECT_KEY` — SonarQube integration
- `KUBE_CONFIG` — base64-encoded kubeconfig for target cluster (used by deploy job)
- `KUBE_NAMESPACE` — target namespace for deployment
- Optional: `TEST_SCRIPT` to override default tests run in `backend`

Helper script `ci/deploy-to-eks.sh` patches the deployment image (expects deployment `health-api` by default).

Before enabling the pipeline, set the CI variables in GitLab and ensure the runner has Docker-in-Docker support for the docker build job.

