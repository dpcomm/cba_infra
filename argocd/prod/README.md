# PROD GitOps bootstrap and migration

The PROD applications are reconciled from this repository by Argo CD:

- `cba-management-prod`
- `cba-was-renewal-prod`
- `cba-email-worker-prod`
- `cba-push-worker-prod`
- `cba-runtime-infra-prod`

Each application uses the existing Helm release name and the image version
already running in OKE. The first synchronization therefore adopts the current
application version rather than replacing it with a placeholder image.

## Prerequisites

- `kubectl` is connected to the `oke-prod` context.
- The `cba-connect-prod` namespace contains `ocir-secret`,
  `cba-was-renewal-env`, and `rabbitmq-auth`.
- The GitHub `production` environments in `dpcomm/cba_was_renewal` and
  `dpcomm/cba_app_management` contain `OCIR_USERNAME`, `OCIR_AUTH_TOKEN`, and
  `GITOPS_TOKEN`, with required reviewers enabled.

## One-time runtime migration

Redis authentication and PVC-backed Redis/RabbitMQ are enabled in
`charts/cba-runtime/values/prod.yaml`. The currently running runtime resources
are Deployments, so do not register the runtime Argo application before this
migration: a Deployment and StatefulSet with the same service selector could
run concurrently.

During a short maintenance window:

1. Choose a Redis password. Update the production app secret source so
   `REDIS_URL` uses `redis://:<password>@redis:6379`.
2. Recreate `cba-was-renewal-env` from that source with
   `scripts/secrets/create-secrets.sh --env prod`.
3. Create `redis-auth` with `scripts/helm/install-runtime-infra.sh --env prod`.
   The script preserves the existing `rabbitmq-auth` Secret unless an explicit
   `RABBITMQ_PASSWORD` is supplied. This step also renders the target runtime
   chart; run it only after the existing runtime Deployments have been removed.
4. Delete only the legacy runtime Deployments, leaving their Services until the
   Helm release recreates the managed objects:

   ```bash
   kubectl --context oke-prod -n cba-connect-prod delete deployment redis rabbitmq
   ```

5. Run `scripts/helm/install-runtime-infra.sh --env prod`, then verify the
   `redis-0` and `rabbitmq-0` Pods and their PVCs are Ready/Bound.
6. Restart the WAS and worker deployments so they load the updated Redis URL.

The runtime contains only cache and queues. This process intentionally permits
their previous contents to be discarded.

## Argo CD bootstrap

Install Argo CD and register the repository without creating applications:

```bash
./scripts/argocd/bootstrap-prod.sh
```

After the runtime migration has completed and the applications are healthy,
register the complete application set:

```bash
./scripts/argocd/bootstrap-prod.sh --applications
kubectl --context oke-prod get applications -n argocd
```

Argo CD has automated sync with self-healing and `prune: false`; it will not
delete resources simply because they are not represented by one of these apps.

## Deployment flow

1. A merge to `master` in `cba_was_renewal` runs tests, builds an immutable
   `linux/arm64` OCIR image, and commits the same tag to the API and both worker
   PROD values files.
2. A merge to `master` in `cba_app_management` builds the management image and
   commits its tag to the management PROD values file.
3. Argo CD observes the `cba_infra/main` commit and synchronizes OKE.
