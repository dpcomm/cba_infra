# CBA Connect DEV GitOps bootstrap

DEV deployment flow:

1. `cba_was_renewal/develop` or the management DEV branch is pushed.
2. GitHub Actions builds an immutable `linux/amd64` image and pushes it to OCIR.
3. GitHub Actions updates the matching image tag in this repository's DEV values.
4. Argo CD detects the `main` revision and syncs the existing Helm release.

## Required GitHub Actions secrets

Add the following repository secrets to both application repositories:

- `OCIR_USERNAME`: OCIR login username
- `OCIR_AUTH_TOKEN`: OCI auth token used for Docker login
- `GITOPS_TOKEN`: fine-grained GitHub PAT with `Contents: Read and write` access to `dpcomm/cba_infra`

The management workflow currently accepts both `feature/v2-migration` and `develop`.
It detects whether the v2 project is under `management-v2/` or at the repository
root, so it continues to work after the legacy root project is replaced. Production
deployment from `master` is intentionally not enabled in this DEV phase.

## One-time Argo CD installation on joey-server

After pulling `cba_infra/main`, run the bootstrap script from the DEV K3s server:

```bash
cd ~/cba_infra
git pull --ff-only origin main
./scripts/argocd/bootstrap-dev.sh
```

To adopt only the WAS API and its two workers during the first test:

```bash
./scripts/argocd/bootstrap-dev.sh --was-only
```

The script prompts for a GitHub token with read access to the private infrastructure
repository, installs Argo CD, registers the repository and applies all DEV applications.
The token is stored only in the Kubernetes repository Secret.

The equivalent manual repository registration is:

```bash
read -s GITHUB_TOKEN
kubectl -n argocd create secret generic cba-infra-repository \
  --from-literal=type=git \
  --from-literal=url=https://github.com/dpcomm/cba_infra.git \
  --from-literal=username=git \
  --from-literal=password="$GITHUB_TOKEN" \
  --dry-run=client -o yaml |
kubectl label --local -f - argocd.argoproj.io/secret-type=repository -o yaml |
kubectl apply -f -
unset GITHUB_TOKEN
```

Apply the DEV applications after this directory is merged into `cba_infra/main`:

```bash
kubectl apply -k argocd/dev
kubectl get applications -n argocd
```

Expected applications:

- `cba-was-renewal-dev`
- `cba-email-worker-dev`
- `cba-push-worker-dev`
- `cba-management-dev`

All applications start with automated sync and `prune: false`. This adopts the
existing DEV resources without allowing the first sync to delete unrelated resources.

## Verification

```bash
kubectl get applications -n argocd
kubectl get deploy,pod -n cba-connect-dev
kubectl logs -n cba-connect-dev deploy/cba-was-renewal --tail=50
kubectl logs -n cba-connect-dev deploy/cba-was-renewal-email-worker --tail=50
kubectl logs -n cba-connect-dev deploy/cba-was-renewal-push-worker --tail=50
```

Do not run `scripts/deploy/deploy-dev.sh` after Argo CD takes ownership. Manual
Helm changes will be reverted by Argo CD self-healing.
