# 2.16.1 to 2.17 Upgrade

```

# 1. Extract the NKP 2.17 air-gapped bundle
tar -xzvf nkp-bundle_v2.17.0_linux_amd64.tar.gz
cd nkp-v2.17.0

# 2. Install the new NKP 2.17 CLI
which nkp
sudo mv /usr/bin/nkp /usr/bin/nkp16
sudo mv ./cli/nkp /usr/bin/nkp

# 3. Verify the CLI version updated successfully
nkp version

# 4. Set Environment Variables for your local container registry
export REGISTRY_URL="https://registry.ntnxlab.local"
export REGISTRY_USERNAME="admin"
export REGISTRY_PASSWORD="Harbor12345"
export REGISTRY_CA="/home/nutanix/certificates/server.crt"

# 5. Push the Konvoy Image Bundle to the local registry
nkp push bundle \
  --bundle ./container-images/konvoy-image-bundle-v2.17.0.tar \
  --to-registry=${REGISTRY_URL}/library \
  --to-registry-username=${REGISTRY_USERNAME} \
  --to-registry-password=${REGISTRY_PASSWORD} \
  --to-registry-ca-cert-file=${REGISTRY_CA}

# 6. Push the Kommander Image Bundle to the local registry
nkp push bundle \
  --bundle ./container-images/kommander-image-bundle-v2.17.0.tar \
  --to-registry=${REGISTRY_URL}/library \
  --to-registry-username=${REGISTRY_USERNAME} \
  --to-registry-password=${REGISTRY_PASSWORD} \
  --to-registry-ca-cert-file=${REGISTRY_CA}

# 7. Set your Target Cluster Name variable
export CLUSTER_NAME="nkp-mgmt-01"

# 8. Upgrade Kommander (Platform Applications)
# Note: --orphan-resources=true is required in 2.17 to transition from Kubecost to OpenCost if you have an active license.
#export KUBECONFIG=/home/nutanix/nkp-v2.16.1/nkp-mgmt-01.conf
sudo chown nutanix:nutanix /home/nutanix/nkp-v2.16.1/nkp-mgmt-01.conf
nkp upgrade kommander \
  --kommander-applications-repository ./application-repositories/kommander-applications-v2.17.0.tar.gz \
  --kubeconfig="/home/nutanix/nkp-v2.16.1/nkp-mgmt-01.conf"
#  --orphan-resources=true

# Upgrade workspaces other than kommander-workspace
nkp get workspaces --kubeconfig="/home/nutanix/nkp-v2.16.1/nkp-mgmt-01.conf"
nkp upgrade workspace default-workspace --kubeconfig="/home/nutanix/nkp-v2.16.1/nkp-mgmt-01.conf"

# 9. Verify the Kommander Applications have successfully rolled out
kubectl -n kommander wait --for condition=Ready helmreleases --all --timeout 15m --kubeconfig="/home/nutanix/nkp-v2.16.1/nkp-mgmt-01.conf"


## Project upgrade (haven't tried)

kubectl get apps -n ${PROJECT_NAMESPACE}
kubectl get apps -n ${PROJECT_NAMESPACE} -o jsonpath='{range .items[*]}{@.spec.appId}
{"----"}{@.spec.version}{"\n"}{end}'

nkp upgrade catalogapp <appdeployment-name> --workspace=my-workspace --project=my-project --to-version=<version.number>


# 10. Upgrade the Cluster Control Plane to Kubernetes 1.34.x (supported in NKP 2.17)
export VM_IMAGE_NAME="nkp-ubuntu-24.04-release-cis-1.34.1-20251206061851.qcow2"

nkp upgrade cluster nutanix \
  --cluster-name ${CLUSTER_NAME} \
  --vm-image ${VM_IMAGE_NAME} \
  --kubeconfig="/home/nutanix/nkp-v2.16.1/nkp-mgmt-01.conf"

# 11. Upgrade Worker Node Pools (Run this if you have defined separate node pools)
# nkp upgrade nodepool <NODEPOOL_NAME> \
#   --cluster-name ${CLUSTER_NAME} \
#   --kubernetes-version v1.34.0 \
#   --vm-image ${VM_IMAGE_NAME}

# 12. Verify the Cluster Nodes are successfully recycled and upgraded
kubectl get nodes -o wide --kubeconfig="/home/nutanix/nkp-v2.16.1/nkp-mgmt-01.conf"

# 13. Fix the missing Konnector-Agent pod (NKP 2.17 Known Issue post-upgrade)
# kubectl delete helmreleaseproxy konnector-agent -n ntnx-system

# 14. (Optional) Check for and upgrade Catalog Applications running in your workspace
# nkp get appdeployments --workspace=<workspace-name> [15]
# nkp upgrade catalogapp <appdeployment-name> --workspace=<workspace-name> --to-version=<new-version.number> 
```