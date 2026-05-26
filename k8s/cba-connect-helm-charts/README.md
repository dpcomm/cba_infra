# cba-connect-helm-charts

Reusable Helm chart for CBA Connect stateless apps.

The chart is shared by dev k3s and prod OKE. Environment differences should live
in values files, not in copied Deployment YAML.

## Dev Render

```bash
helm template cba-was-renewal ./k8s/cba-connect-helm-charts \
  -n cba-dev \
  -f ./k8s/cba-connect-helm-charts/values/cba-was-renewal-dev.yaml
```

## Dev Install

Before installing with Helm, remove or migrate existing non-Helm resources with
the same names. Helm cannot automatically take ownership of resources that were
created by Kustomize.

```bash
helm upgrade --install cba-was-renewal ./k8s/cba-connect-helm-charts \
  -n cba-dev \
  -f ./k8s/cba-connect-helm-charts/values/cba-was-renewal-dev.yaml
```

## Values Convention

- `*-dev.yaml`: dev k3s values.
- `*-prod.yaml`: prod OKE values.
- Secrets are referenced by name only. Create them with scripts under
  `scripts/secrets/`.
