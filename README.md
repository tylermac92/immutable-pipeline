# Immutable Infrastructure Pipeline

Automated image baking and infrastructure deployment using Packer, Ansible, and Terraform on GCP.

## Architecture
Code change → Packer (image bake) → Goss (validation) → Terraform (deploy) → Load Balancer

## Prerequisites

### Tools
| Tool | Version |
|---|---|
| Google Cloud SDK | 571.0.0+ |
| Packer | 1.15.4 |
| OpenTofu | 1.12.1 |
| ansible-core | 2.17.9 |
| Docker | any recent version |

### GCP Project Setup

1. Create a GCP project and enable required APIs:
```bash
gcloud services enable \
  compute.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  oslogin.googleapis.com
```

2. Create two service accounts:
```bash
gcloud iam service-accounts create sa-packer-builder \
  --display-name="Packer Image Builder"

gcloud iam service-accounts create sa-terraform-provisioner \
  --display-name="Terraform Infrastructure Provisioner"

gcloud iam service-accounts create sa-compute-instance \
  --display-name="Compute Instance Runtime"
```

3. Grant required IAM roles:

**sa-packer-builder:**
```bash
for role in \
  roles/compute.instanceAdmin.v1 \
  roles/compute.storageAdmin \
  roles/iam.serviceAccountUser \
  roles/iap.tunnelResourceAccessor; do
  gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:sa-packer-builder@PROJECT_ID.iam.gserviceaccount.com" \
    --role="${role}"
done
```

**sa-terraform-provisioner:**
```bash
for role in \
  roles/compute.instanceAdmin.v1 \
  roles/compute.networkAdmin \
  roles/compute.loadBalancerAdmin \
  roles/compute.storageAdmin \
  roles/compute.securityAdmin \
  roles/iam.serviceAccountUser; do
  gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:sa-terraform-provisioner@PROJECT_ID.iam.gserviceaccount.com" \
    --role="${role}"
done
```

**sa-compute-instance:**
```bash
for role in \
  roles/logging.logWriter \
  roles/monitoring.metricWriter; do
  gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="serviceAccount:sa-compute-instance@PROJECT_ID.iam.gserviceaccount.com" \
    --role="${role}"
done
```

4. Create the Terraform state bucket:
```bash
gsutil mb -p PROJECT_ID -l us-central1 -b on gs://PROJECT_ID-tfstate
gsutil versioning set on gs://PROJECT_ID-tfstate
```

5. Grant the Terraform SA access to the state bucket:
```bash
gsutil iam ch \
  serviceAccount:sa-terraform-provisioner@PROJECT_ID.iam.gserviceaccount.com:roles/storage.admin \
  gs://PROJECT_ID-tfstate
```

6. Configure Workload Identity Federation for GitHub Actions:
```bash
# Create pool
gcloud iam workload-identity-pools create "github-actions-pool" \
  --location="global"

# Create provider
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --location="global" \
  --workload-identity-pool="github-actions-pool" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='YOUR_GITHUB_ORG/YOUR_REPO'"

# Bind SAs to pool
for sa in sa-packer-builder sa-terraform-provisioner; do
  gcloud iam service-accounts add-iam-policy-binding \
    ${sa}@PROJECT_ID.iam.gserviceaccount.com \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/attribute.repository/YOUR_GITHUB_ORG/YOUR_REPO"
done
```

## Local Development

### Setup

```bash
# Clone the repository
git clone https://github.com/tylermac92/immutable-pipeline.git
cd immutable-pipeline

# Create Python virtual environment
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
ansible-galaxy collection install -r ansible/requirements.yml

# Configure environment variables
cp .envrc.example .envrc
# Edit .envrc with your project values
source .envrc
```

### Running Locally

**Test Ansible changes (fast, ~90 seconds):**
```bash
./scripts/test-ansible-local.sh
./scripts/test-goss-local.sh
```

**Bake a new image (~20 minutes):**
```bash
GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=${PACKER_SA} \
packer build -var="project_id=${PROJECT_ID}" packer/
```

**Deploy infrastructure:**
```bash
cd terraform
IMAGE_NAME=$(python3 -c "
import json
with open('../packer/manifest.json') as f:
    m = json.load(f)
last_uuid = m['last_run_uuid']
build = next(b for b in m['builds'] if b['packer_run_uuid'] == last_uuid)
print(build['artifact_id'])
")
tofu apply -var="project_id=${PROJECT_ID}" -var="image_name=${IMAGE_NAME}" \
  -var="sa_instance_runtime_email=sa-compute-instance@${PROJECT_ID}.iam.gserviceaccount.com"
```

## CI/CD Pipeline

The GitHub Actions pipeline triggers on changes to `packer/`, `ansible/`, `validation/`, or `terraform/` directories.

**Required GitHub Secrets:**
| Secret | Description |
|---|---|
| `GCP_PROJECT_ID` | GCP project ID |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Full WIF provider resource path |
| `GCP_PACKER_SA` | Packer service account email |
| `GCP_TERRAFORM_SA` | Terraform service account email |

**Pipeline stages:**
1. `build-image` — Packer bakes and validates a new hardened Ubuntu image
2. `deploy-infrastructure` — Terraform deploys the image to a regional MIG behind an HTTP(S) load balancer

## Known Limitations

- Local authentication uses a service account key file at `~/.config/gcloud/sa-terraform-provisioner-key.json`. CI uses Workload Identity Federation instead.
- The default Compute Engine service account has `roles/editor` which should be disabled in a production hardening pass.
- Goss validation runs against the GCP build VM only. Service state checks are skipped in local Docker testing due to the absence of systemd.
