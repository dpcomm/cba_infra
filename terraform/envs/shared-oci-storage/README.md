# Shared OCI Object Storage

This environment manages private application buckets shared by the DEV K3s and
PROD OKE workloads:

- `cba-connect-dev`
- `cba-connect-prod`

It uses a separate Terraform state key at
`envs/shared-oci-storage/terraform.tfstate` in `cba-terraform-state`.

## Prerequisites

- Terraform `1.10.x`. OCI Object Storage's S3-compatible API does not support
  the chunked state upload used by Terraform `1.11+`.
- OCI API credentials available through `~/.oci/config`.
- OCI Object Storage Customer Secret Key credentials configured for the
  Terraform S3 backend. The selected AWS profile must use the OCI Customer
  Secret access key and secret key, not unrelated AWS credentials.
- A local `terraform.tfvars` containing `compartment_ocid`.

## Apply

```bash
cd terraform/envs/shared-oci-storage
cp terraform.tfvars.example terraform.tfvars
terraform version # Verify 1.10.x
terraform init -reconfigure
terraform plan -out=tfplan
terraform apply tfplan
```

If the Customer Secret Key is kept in a non-default AWS profile, select it
before running Terraform:

```bash
export AWS_PROFILE=<oci-object-storage-profile>
export AWS_SDK_LOAD_CONFIG=1
```
