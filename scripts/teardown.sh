#!/bin/bash

cd terraform
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/sa-terraform-provisioner-key.json

tofu destroy \
  -var="project_id=${PROJECT_ID}" \
  -var="image_name=$(python3 -c "
import json
with open('../packer/manifest.json') as f:
    m = json.load(f)
last_uuid = m['last_run_uuid']
build = next(b for b in m['builds'] if b['packer_run_uuid'] == last_uuid)
print(build['artifact_id'])
")" \
  -var="sa_instance_runtime_email=sa-compute-instance@${PROJECT_ID}.iam.gserviceaccount.com"

# Clean up images and NAT
gcloud compute images list \
  --project=${PROJECT_ID} \
  --filter="family=hardened-ubuntu" \
  --format="value(name)" \
  | xargs -r gcloud compute images delete --project=${PROJECT_ID} --quiet

gcloud compute routers delete packer-nat-router \
  --region=${REGION} --project=${PROJECT_ID} --quiet 2>/dev/null || true
