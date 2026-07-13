# CBA Infra Guide

`cba_infra`는 CBA Connect의 Kubernetes 배포 파일, Helm values, 운영 스크립트, Terraform 구성을 관리하는 저장소입니다.

## 현황

### Dev

- 실행 위치: 온프레미스 k3s (`joey-server`)
- 외부 진입: Docker Caddy `80/443` -> ingress-nginx NodePort `32080` -> k3s ClusterIP Service
- 운영 대상:
  - `cba-was-renewal`
  - `cba-management`
  - `cba-was-renewal-email-worker`
  - `cba-was-renewal-push-worker`
- DB/Redis: NAS Docker 사용
- 기존 Docker Immich는 유지

### Prod

- OCI Load Balancer -> ingress-nginx -> Kubernetes Ingress -> ClusterIP Service -> Pod
- Kubernetes namespace: `cba-connect-prod`
- 우선 이전 대상: `cba-was-renewal`
- 추후 단계: admin web, user web, worker, Redis/RabbitMQ 이전
- MySQL은 OKE 내부에 배포하지 않고 OCI MySQL HeatWave에 연결
- MySQL용 PVC는 사용하지 않음

## 도메인 정책

### Prod

```text
recba.me        -> 사용자 웹 또는 메인
www.recba.me    -> recba.me
api.recba.me    -> NestJS API
admin.recba.me  -> 관리자 웹
```

### Dev

```text
dev.recba.me        -> dev 사용자 웹 또는 landing
api.dev.recba.me    -> dev NestJS API
admin.dev.recba.me  -> dev 관리자 웹
```

API 서브도메인에서는 `/api` prefix를 쓰지 않습니다.

```text
https://api.recba.me/docs
https://api.recba.me/auth/login
https://api.dev.recba.me/docs
https://api.dev.recba.me/auth/login
```

NestJS 애플리케이션 쪽에서는 아래를 계속 지켜야 합니다.

- Swagger 경로: `/docs`
- `app.setGlobalPrefix('api')` 미사용
- Controller 경로에 `api/` 하드코딩 금지
- 프론트엔드 API base URL도 서브도메인 기준 사용

## 저장소 구조

```text
terraform/
  modules/
    k8s-namespaces/
    oci-network/
    oke-cluster/
  envs/
    dev-k3s/
    prod-oke/

charts/
  cba-app/
  cba-runtime/

scripts/
  secrets/
  deploy/
  helm/
  diagnostics/
```

실제 실행 엔트리포인트만 남깁니다.

```text
scripts/secrets/create-secrets.sh --env <dev|prod>
scripts/helm/install-runtime-infra.sh --env <dev|prod>
scripts/deploy/deploy-prod.sh
scripts/diagnostics/check-cluster.sh --env <dev|prod>
```

환경별 wrapper 스크립트는 두지 않습니다. 같은 기능이 여러 이름으로 보이면 실행 경로가 헷갈리기 때문입니다.

## Helm Chart 정책

현재 앱 배포의 기본 경로는 Helm입니다.

- `charts/cba-app`: 공용 앱 chart
- `charts/cba-app/values/dev/*.yaml`: dev 앱 values
- `charts/cba-app/values/prod/*.yaml`: prod 앱 values
- `charts/cba-runtime`: Redis/RabbitMQ 같은 앱 런타임 chart

앱 Deployment/Service/Ingress는 Helm만 소유합니다. 예전 Kustomize app base/overlay는 제거했습니다.

외부 인프라 컴포넌트는 Helm chart를 직접 만들지 않고, 설치 스크립트에서 공식 chart에 필요한 최소 `--set` 값만 주입합니다.

- ingress-nginx: `scripts/helm/install-dev-ingress.sh`, `scripts/helm/install-prod-ingress-nginx.sh`
- cert-manager + prod ClusterIssuer: `scripts/helm/install-prod-cert-manager.sh`

기본 앱 chart 렌더 예시:

```bash
helm template cba-was-renewal ./charts/cba-app \
  --namespace cba-connect-dev \
  -f ./charts/cba-app/values/dev/cba-was-renewal.yaml
```

## Secret 정책

민감정보는 git에 올리지 않습니다.

- `.env.dev`
- `.env.prod`
- `.ocir.env`
- OCI Auth Token
- DB password
- JWT secret
- `terraform.tfvars`

Kubernetes Secret은 Terraform으로 관리하지 않습니다. Secret 생성은 스크립트로만 합니다.

```bash
./scripts/secrets/create-secrets.sh --env dev
./scripts/secrets/create-secrets.sh --env prod
```

`terraform.tfvars`는 로컬 전용 파일입니다. `prod-oke`에서는 최소한 아래 값이 필요합니다.

```hcl
compartment_ocid    = "실제 OCI compartment 또는 tenancy OCID"
availability_domain = "실제 AD 이름"
node_image_id       = "실제 OKE worker image OCID"
node_ssh_public_key = "실제 SSH public key"
```

## Terraform 구성

### 역할 분리

- `modules`: 재사용 가능한 리소스 정의
- `envs/dev-k3s`: dev k3s 내부 namespace 관리
- `envs/prod-oke`: OCI 네트워크와 OKE 기반 리소스 생성

### `prod-oke`가 만드는 리소스

- VCN
- Internet Gateway
- NAT Gateway
- public/private route table
- public/private security list
- public/private subnet
- MySQL HeatWave 연결용 NSG
- reserved public IP
- OKE cluster
- OKE node pool

### Remote Backend

Terraform state는 OCI Object Storage의 S3-compatible backend에 저장합니다.

```text
bucket: cba-terraform-state
dev key:  envs/dev-k3s/terraform.tfstate
prod key: envs/prod-oke/terraform.tfstate
```

backend 접근에는 OCI Customer Secret Key 기반 S3 호환 자격증명이 필요합니다.

```bash
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
```

OCI 리소스 생성에는 별도로 `~/.oci/config`의 OCI API 인증이 필요합니다.

### apply 전 검증

```bash
cd terraform/envs/prod-oke
terraform fmt -recursive
terraform validate
terraform plan
```

현재 실제 plan 기준 기대값:

```text
Plan: 14 to add, 0 to change, 0 to destroy.
```

`plan`은 미리보기이고, 실제 생성은 `terraform apply`에서만 일어납니다.

현재 `prod-oke` Terraform은 MySQL HeatWave DB system 자체를 만들지는 않습니다. 대신 OKE private subnet에서 MySQL HeatWave로 접근할 때 사용할 NSG를 준비합니다.

## Prod 최초 구축 순서

1. OCI Object Storage bucket과 backend 자격증명 준비
2. `terraform/envs/prod-oke/terraform.tfvars`에 실제 값 입력
3. `terraform plan`으로 생성 대상 확인
4. 승인 후 `terraform apply`
5. OKE kubeconfig 설정
6. ingress-nginx 설치
7. cert-manager와 prod ClusterIssuer 설치
9. prod namespace/Secret 준비
10. 고정 이미지 태그로 Helm render 확인
11. 승인 후 Helm 배포
12. DNS 전환 후 새 인증서 발급과 ingress 확인

예시 명령:

```bash
cd terraform/envs/prod-oke
terraform apply

cd ../../..
./scripts/helm/install-prod-ingress-nginx.sh
./scripts/helm/install-prod-cert-manager.sh
./scripts/secrets/create-secrets.sh --env prod
./scripts/deploy/deploy-prod.sh --was-tag <FIXED_WAS_IMAGE_TAG>
```

`deploy-prod.sh`는 기본적으로 dry-run 모드입니다. 실제 적용은 명시적으로 승인할 때만 실행합니다.

```bash
./scripts/deploy/deploy-prod.sh --was-tag <FIXED_WAS_IMAGE_TAG> --execute
./scripts/deploy/deploy-prod.sh --was-tag <FIXED_WAS_IMAGE_TAG> --management-tag <FIXED_MANAGEMENT_IMAGE_TAG> --with-workers --execute
```

## Reserved Public IP 주의

Terraform은 reserved public IP를 생성합니다. 이 IP를 ingress-nginx의 OCI Load Balancer가 실제로 사용하게 하려면, ingress-nginx 설치 시 별도 연결 설정이 필요합니다.

현재 prod ingress-nginx 설치 스크립트는 LoadBalancer 타입과 flexible shape만 설정합니다. reserved IP를 고정 진입점으로 쓸 계획이면, Terraform apply 이후 출력된 IP를 기준으로 ingress-nginx Service annotation 연결 절차를 추가로 진행해야 합니다.

## TLS / cert-manager

기존 단일 서버 클러스터의 TLS Secret은 새 OKE로 복사하지 않습니다.

- 기존 인증서는 `recba.me` 단일 호스트용이었습니다.
- 새 OKE에서는 `scripts/helm/install-prod-cert-manager.sh`가 `letsencrypt-prod` ClusterIssuer를 적용하고, prod Helm Ingress를 기준으로 새 인증서를 발급받습니다.
- API 인증서는 `api-recba-me-tls`, admin 인증서는 `admin-recba-me-tls`로 분리합니다.
- HTTP-01 challenge를 쓰므로, DNS가 새 OCI Load Balancer를 가리킨 뒤 cert-manager가 challenge 요청을 받아야 인증서가 정상 발급됩니다.

확인 명령:

```bash
kubectl get clusterissuer
kubectl get certificate -n cba-connect-prod
kubectl describe certificate api-recba-me-tls -n cba-connect-prod
kubectl describe certificate admin-recba-me-tls -n cba-connect-prod
kubectl get secret api-recba-me-tls admin-recba-me-tls -n cba-connect-prod
```

## Dev 배포

DEV 애플리케이션 배포는 GitHub Actions와 Argo CD가 소유합니다.

1. `cba_was_renewal/develop` 또는 관리 웹 DEV 대상 브랜치에 푸시합니다.
2. GitHub Actions가 OCIR에 고정 `dev-*` 태그 이미지를 푸시합니다.
3. 같은 workflow가 `cba_infra/main`의 DEV Helm values 이미지 태그를 갱신합니다.
4. Argo CD가 `cba-connect-dev`의 Helm release를 자동 동기화합니다.

클러스터 최초 준비와 진단에만 아래 명령을 사용합니다.

```bash
./scripts/helm/install-dev-ingress.sh
./scripts/secrets/create-secrets.sh --env dev
./scripts/helm/install-runtime-infra.sh --env dev
./scripts/argocd/bootstrap-dev.sh
./scripts/diagnostics/check-cluster.sh --env dev
```

Argo CD가 소유하는 DEV release에 수동 Helm 배포를 실행하지 않습니다. 변경은
항상 GitOps values commit으로 반영합니다.

## Prod 배포 원칙

- prod 실제 apply는 수동 승인 후 실행
- prod 이미지는 고정 태그만 사용
- dev 가변 태그 금지
- legacy `cba-was` / `cba-was-renew` 배포 금지
- 기본 배포 대상 WAS는 `cba-was-renewal`만 사용
- admin/worker prod 배포는 `deploy-prod.sh`의 `--management-tag`, `--with-workers`를 명시한 경우에만 수행

## OCIR 이미지 정리 정책

OCIR에는 배포 추적용 고정 태그가 쌓입니다. 운영 원칙은 “현재 배포 중인 태그는 절대 지우지 않고, 오래된 dev 태그부터 자동/수동 정리”입니다.

권장 보관 기준:

- `dev-*`: 최근 20개 또는 최근 14일만 유지
- `prod-*`: 최근 10개 이상 또는 최근 90일 유지
- 현재 Helm release가 사용하는 태그는 항상 유지

정리 전에 현재 사용 중인 이미지를 먼저 확인합니다.

```bash
kubectl get pods -n cba-connect-dev -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'
kubectl get pods -n cba-connect-prod -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'
helm list -n cba-connect-dev
helm list -n cba-connect-prod
```

콘솔에서는 `Developer Services > Container Registry > Repositories > cba_was_renew`에서 오래된 `dev-*` 이미지를 먼저 정리합니다. prod 태그는 롤백 지점이므로 수동으로 확인한 뒤 삭제합니다.

## 진단 명령

```bash
./scripts/diagnostics/check-cluster.sh --env dev
./scripts/diagnostics/check-cluster.sh --env prod

kubectl get pods -n cba-connect-dev
kubectl get pods -n cba-connect-prod
kubectl describe ingress -n cba-connect-dev
kubectl describe ingress -n cba-connect-prod
```

## Troubleshooting

- `OCIR 401 Unauthorized`
  - OCIR username 형식과 auth token 확인
- `ImagePullBackOff`
  - 이미지 태그, 아키텍처(`amd64`/`arm64`), `ocir-secret` 확인
- ingress host mismatch
  - DNS host, Ingress host, Caddy host를 같은 값으로 맞춤
- `/docs 404`
  - NestJS Swagger 경로가 `/docs`인지 확인
- `/api-docs`만 열림
  - 새 이미지가 실제로 rollout 되었는지 확인
- dev에서 외부 접속 불가
  - Docker Caddy -> `172.17.0.1:32080` proxy 확인
- ClusterIP가 외부에서 안 열림
  - 정상입니다. 외부 진입은 ingress 또는 gateway가 담당합니다.
