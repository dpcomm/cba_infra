terraform {
  # OCI's S3-compatible API rejects the chunked state upload used by 1.11+.
  required_version = "~> 1.10.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "cba-terraform-state"
    key    = "envs/shared-oci-storage/terraform.tfstate"
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
