#!/bin/bash

export CLUSTER_NAME="zy-nkp-mgmt"

export NUTANIX_ENDPOINT="https://10.129.42.11:9440/"

export NUTANIX_USER=zhouyi@ntnxlab.local
export NUTANIX_PASSWORD=P@ssw0rd

export AIRGAPPED=true
export INSECURE=true

export NUTANIX_CLUSTER="NKP"
export STORAGE_CONTAINER_NAME="SelfServiceContainer"

export CONTROLPLANE_IP="10.129.42.200"
export SERVICE_LB_IP_RANGE="10.129.42.201-10.129.42.205"

export SUBNET="Machine_Network_42"

export VM_IMAGE="nkp-ubuntu-22.04-release-cis-1.33.5-20251108010758.qcow2"

export KUBERNETES_PODS_NETWORK="192.168.0.0/16"
export KUBERNETES_SERVICES_NETWORK="10.96.0.0/12"

export SSH_PUBLIC_KEY_FILE="/home/nutanix/.ssh/id_rsa.pub"

export CATEGORIES="Owner=zy"

export REGISTRY_FQDN="zy-registry.ntnxlab.local"
export REGISTRY_URL="https://zy-registry.ntnxlab.local"
export REGISTRY_USERNAME="admin"
export REGISTRY_PASSWORD="Harbor12345"
export REGISTRY_MIRROR_URL="https://zy-registry.ntnxlab.local/library"
export REGISTRY_CA="/home/nutanix/certs/registry_ca.crt"

mkdir -p /home/nutanix/certs
openssl s_client -showcerts -connect ${REGISTRY_FQDN}:443 </dev/null 2>/dev/null | openssl x509 -outform PEM > ${REGISTRY_CA}

nkp create cluster nutanix \
--self-managed \
--airgapped=${AIRGAPPED:-false} \
\
--cluster-name=${CLUSTER_NAME} \
--endpoint=${NUTANIX_ENDPOINT} \
--insecure=${INSECURE:=false} \
--ssh-public-key-file=${SSH_KEY_FILE} \
--csi-storage-container=${STORAGE_CONTAINER_NAME} \
--kubernetes-pod-network-cidr=${KUBERNETES_PODS_NETWORK:-"192.168.0.0/16"} \
--kubernetes-service-cidr=${KUBERNETES_SERVICES_NETWORK:-"10.96.0.0/12"} \
--kubernetes-service-load-balancer-ip-range=${SERVICE_LB_IP_RANGE} \
\
--control-plane-endpoint-ip=${CONTROLPLANE_IP} \
--control-plane-endpoint-port=6443 \
--control-plane-prism-element-cluster=${NUTANIX_CLUSTER} \
--control-plane-subnets=${SUBNET} \
--control-plane-vm-image=${VM_IMAGE} \
--control-plane-cores-per-vcpu=1 \
--control-plane-vcpus=4 \
--control-plane-memory=16 \
--control-plane-replicas=3 \
--control-plane-pc-categories=${CATEGORIES} \
\
--worker-prism-element-cluster=${NUTANIX_CLUSTER} \
--worker-subnets=${SUBNET} \
--worker-vm-image=${VM_IMAGE} \
--worker-cores-per-vcpu=1 \
--worker-vcpus=8 \
--worker-memory=32 \
--worker-replicas=4 \
--worker-pc-categories=${CATEGORIES} \
\
--registry-url=${REGISTRY_URL} \
--registry-cacert=${REGISTRY_CA} \
--registry-username=${REGISTRY_USERNAME} \
--registry-password=${REGISTRY_PASSWORD} \
\
--registry-mirror-url=${REGISTRY_MIRROR_URL} \
--registry-mirror-cacert=${REGISTRY_CA} \
--registry-mirror-username=${REGISTRY_USERNAME} \
--registry-mirror-password=${REGISTRY_PASSWORD} \
\
--verbose 5

./nkp-v2.16.1/cli/nkp push bundle \
--bundle "nkp-v2.16.1/container-images/konvoy-image-bundle-v2.16.1.tar" \
--bundle "nkp-v2.16.1/container-images/kommander-image-bundle-v2.16.1.tar" \
--to-registry="https://zy-registry.ntnxlab.local/library" \
--to-registry-username="admin" \
--to-registry-password="Harbor12345" \
--to-registry-ca-cert-file="/home/nutanix/certs/registry_ca.crt"