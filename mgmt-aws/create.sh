#!/bin/bash
export AWS_REGION=ap-southeast-1
export AWS_PROFILE=default

export CLUSTER_NAME="nkp"

export REGISTRY_MIRROR_URL="https://registry-1.docker.io"
export REGISTRY_MIRROR_USERNAME="rhapsody008"
export REGISTRY_MIRROR_PASSWORD="<REGISTRY_PAT>"

export REGISTRY_URL="https://docker.io"
export REGISTRY_USERNAME="rhapsody008"
export REGISTRY_PASSWORD="<REGISTRY_PAT>"

export CONTROLPLANE_INSTANCE_TYPE="c5.2xlarge"
export CONTROLPLANE_REPLICAS=1
export CONTROLPLANE_IAM_INSTANCE_PROFILE="control-plane.cluster-api-provider-aws.sigs.k8s.io"

export WORKER_INSTANCE_TYPE="m5.2xlarge"
export WORKER_REPLICAS=4
export WORKER_IAM_INSTANCE_PROFILE="nodes.cluster-api-provider-aws.sigs.k8s.io"

export KUBERNETES_VERSION="1.33.5"
export SSH_USERNAME="nutanix"
export SSH_PUBLIC_KEY_FILE="/home/nutanix/.ssh/id_rsa.pub"

export VPC_ID="vpc-0e6f75146ad6f6c0d"
export SUBNET_IDS="subnet-01eb9268048b70d76,subnet-02b08e6579d7d9b9b"

export AMI_ID="ami-0a74f8c267051d0ea"

#----------- Create NKP Mgmt Cluster ------------

echo "Creating NKP Management Cluster ..."

cd /home/nutanix/mynkp

nohup nkp create cluster aws \
    --cluster-name=${CLUSTER_NAME} \
    --ami=${AMI_ID} \
    --region=${AWS_REGION} \
    --kubernetes-version=${KUBERNETES_VERSION} \
    --additional-tags=owner="yi.zhou@nutanix.com" \
    --with-aws-bootstrap-credentials=true \
    \
    --vpc-id=${VPC_ID} \
    --subnet-ids=${SUBNET_IDS} \
    --control-plane-instance-type=${CONTROLPLANE_INSTANCE_TYPE} \
    --control-plane-replicas=${CONTROLPLANE_REPLICAS} \
    --control-plane-iam-instance-profile=${CONTROLPLANE_IAM_INSTANCE_PROFILE}\
    --worker-instance-type=${WORKER_INSTANCE_TYPE} \
    --worker-replicas=${WORKER_REPLICAS} \
    --worker-iam-instance-profile=${WORKER_IAM_INSTANCE_PROFILE} \
    \
    --registry-mirror-url=${REGISTRY_MIRROR_URL} \
    --registry-mirror-username=${REGISTRY_MIRROR_USERNAME} \
    --registry-mirror-password=${REGISTRY_MIRROR_PASSWORD} \
    \
    --ssh-username=${SSH_USERNAME} \
    --ssh-public-key-file=${SSH_PUBLIC_KEY_FILE} \
    \
    --self-managed -v 5 &> nkp_create_cluster_aws.log &

