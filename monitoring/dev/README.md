# DEV Kubernetes monitoring

This directory installs a resource-limited `kube-prometheus-stack` on the
single-node DEV K3s cluster.

- Prometheus: 7-day retention, 10 GiB PVC
- Grafana: 5 GiB PVC
- kube-state-metrics and node-exporter
- Argo CD ServiceMonitors and a starter dashboard
- Grafana ingress: `monitoring.dev.recba.me`
- Argo CD ingress: `argocd.dev.recba.me`

After merging to `cba_infra/main`, enable it on `joey-server`:

```bash
cd ~/cba_infra
git pull --ff-only origin main
./scripts/argocd/enable-dev-monitoring.sh
```

Get the generated Grafana password:

```bash
kubectl get secret monitoring-grafana -n monitoring \
  -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

The username is `admin`.

Port-forward access:

```bash
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
kubectl port-forward -n argocd svc/argocd-server 8080:443
```

Open `http://127.0.0.1:3000` for Grafana and `https://127.0.0.1:8080` for
Argo CD. The Argo CD URL uses its self-signed certificate.

For access from another machine without exposing the port-forwards, run the two
`kubectl port-forward` commands on `joey-server` and create an SSH tunnel from
the client machine:

```bash
ssh \
  -L 3000:127.0.0.1:3000 \
  -L 8080:127.0.0.1:8080 \
  joey@192.168.0.217
```

## DEV domains through Caddy

Create these DNS A records with the same address as `api.dev.recba.me`:

```text
monitoring.dev.recba.me -> 121.143.179.182
argocd.dev.recba.me     -> 121.143.179.182
```

Both Kubernetes Ingress resources are already included. Add both hosts to the
existing Caddy configuration and use the same reverse proxy target currently
used by `api.dev.recba.me`:

```caddyfile
monitoring.dev.recba.me,
argocd.dev.recba.me {
    reverse_proxy <same K3s ingress upstream as api.dev.recba.me>
}
```

Reload Caddy after editing its host-mounted Caddyfile:

```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```
