# YAS GitOps

GitOps manifests and Helm charts for the YAS CD assignment.

## Layout

- `charts/`: YAS application Helm charts.
- `infrastructure/`: database, messaging, identity, cache, and service mesh charts.
- `observability/`: optional monitoring and tracing charts for the advanced scope.
- `environments/test`: values used by the Jenkins `developer_build` job.
- `environments/dev`: Argo CD application definitions for the dev environment.
- `environments/staging`: Argo CD application definitions for the staging environment.

Jenkins updates image tags under `environments/*/services/*.yaml`. Argo CD reconciles `dev` and `staging`; `developer_build` clones this repo and deploys a per-developer test namespace with branch-specific image tags.
