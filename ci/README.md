CI variables required for secure pipeline

This repository's GitLab CI configuration expects the following CI variables to be set in your project or group settings (do not commit secrets into source):

- CI_REGISTRY: URL of the container registry (e.g. registry.gitlab.com)
- CI_REGISTRY_USER: username with push rights (prefer CI_JOB_TOKEN or a robot account)
- CI_REGISTRY_PASSWORD: password or token for the registry (marked as masked/secret)
- SONAR_HOST_URL: SonarQube server URL (e.g. https://sonar.example.com or http://sonar:9000 for self-hosted)
- SONAR_TOKEN: Sonar token with execute permissions (masked)
- KUBE_CONFIG: base64-encoded kubeconfig string for deploy jobs (masked)

Notes:
- Use GitLab CI/CD masked variables for secrets and avoid printing them in job logs.
- Prefer ephemeral tokens or robot accounts for CI instead of admin credentials.
- Do not add secrets into the repo or logs. If a token is accidentally exposed, rotate it immediately.

How image push works

The `docker-build` job will build an image and attempt to log in and push only when `CI_REGISTRY`, `CI_REGISTRY_USER`, and `CI_REGISTRY_PASSWORD` are set. If they are not set the job will still build the image locally on the runner but will not push.

How to configure Sonar

Set `SONAR_HOST_URL` and `SONAR_TOKEN` in CI variables. The `sonarqube-scan` job will run when these variables are present.

Security checklist before pushing:
- Ensure `.gitignore` excludes build caches like `frontend/.dart_tool`.
- Remove sensitive files from commits and use `git rm --cached <file>` if necessary.
- Rotate any tokens that were created during local testing.
