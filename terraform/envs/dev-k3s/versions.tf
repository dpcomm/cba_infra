terraform {
  # OCI's S3-compatible API rejects the chunked state upload used by 1.11+.
  required_version = "~> 1.10.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
  }

  # ── Remote Backend (OCI Object Storage / S3-compatible) ──
  # OCI Object Storage의 S3 호환 API를 사용합니다.
  # 사전 준비:
  #   1. OCI Object Storage에 "cba-terraform-state" 버킷 생성
  #   2. ~/.aws/credentials 또는 환경변수에 OCI S3 Compatibility 키 설정
  #      export AWS_ACCESS_KEY_ID="<customer_secret_key_id>"
  #      export AWS_SECRET_ACCESS_KEY="<customer_secret_key>"
  # ──────────────────────────────────────────────────────────
  backend "s3" {
    bucket = "cba-terraform-state"
    key    = "envs/dev-k3s/terraform.tfstate"
    region = "ap-chuncheon-1"
    endpoints = {
      s3 = "https://axdhp42jvukm.compat.objectstorage.ap-chuncheon-1.oraclecloud.com"
    }

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
