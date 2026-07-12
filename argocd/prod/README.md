# PROD management GitOps bootstrap

The production management workflow builds `linux/arm64` from the repository
root when `master` is pushed, publishes an immutable image to OCIR and updates
`charts/cba-app/values/prod/cba-management.yaml`.

Before enabling the workflow, install the production Argo CD application from
a workstation whose kubeconfig points to the PROD OKE cluster:

```bash
cd ~/cba/cba_infra
./scripts/argocd/bootstrap-prod-management.sh
```

The script adopts only the existing `cba-management` Helm resources. The
initial values use the image that was already running at migration time, so the
first synchronization does not change the production version.

Configure a GitHub `production` environment in `dpcomm/cba_app_management` and
enable required reviewers before merging the new root project to `master`.
