# YAS GitOps

GitOps repo for Project 2 CD.

This repo follows the dynamic Helm chart approach:

```text
Jenkins developer_build
-> update helm/yas/values-<env>.yaml
-> push this GitOps repo
-> Argo CD syncs YAS to Kubernetes
```

## Layout

```text
argocd/
  project.yaml
  applications/
    yas-dev.yaml
    yas-staging.yaml

helm/
  yas/
    Chart.yaml
    values.yaml
    values-dev.yaml
    values-staging.yaml
    templates/

jenkins/
  Jenkinsfile.developer_build
  Jenkinsfile.cleanup
  scripts/
```

## Environments

- `dev` syncs from Git branch `main` using `helm/yas/values-dev.yaml`.
- `staging` syncs from Git branch `staging` using `helm/yas/values-staging.yaml`.

## Jenkins

`developer_build` accepts service branch parameters such as:

```text
TAX_SERVICE_BRANCH=dev_tax_service_test
```

The job resolves the branch to a short commit tag from `thu2005/yas`, updates the matching image tag in `helm/yas/values-<env>.yaml`, commits, and pushes this repo.

`cleanup` resets selected services, or all services, back to `main`.
