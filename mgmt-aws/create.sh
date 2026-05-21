#!/bin/bash
export AWS_REGION=ap-southeast-1
export AWS_PROFILE=default

export CLUSTER_NAME="zy-nkp-mgmt"

export REGISTRY_MIRROR_URL="https://registry-1.docker.io"
export REGISTRY_MIRROR_USERNAME="rhapsody008"
export REGISTRY_MIRROR_PASSWORD=""

export REGISTRY_URL="https://docker.io"
export REGISTRY_USERNAME="rhapsody008"
export REGISTRY_PASSWORD=""

export CONTROLPLANE_INSTANCE_TYPE="c5.2xlarge"
export CONTROLPLANE_REPLICAS=3
export CONTROLPLANE_IAM_INSTANCE_PROFILE="control-plane.cluster-api-provider-aws.sigs.k8s.io"

export WORKER_INSTANCE_TYPE="m5.2xlarge"
export WORKER_REPLICAS=4
export WORKER_IAM_INSTANCE_PROFILE="nodes.cluster-api-provider-aws.sigs.k8s.io"

export KUBERNETES_VERSION="1.34.3"
export SSH_USERNAME="nutanix"
export SSH_PUBLIC_KEY_FILE="/home/nutanix/.ssh/id_rsa.pub"

export VPC_ID="vpc-0806975f9ad0c5ed8"
export SUBNET_IDS="subnet-02122c1c14aac1769,subnet-00d0270dcb7249e49"

export ADDITIONAL_SECURITY_GROUP_IDs="sg-0d2c5dbed55592096"

export AMI_ID="ami-01c7e34b5ac818668"

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
    --additional-security-group-ids=${ADDITIONAL_SECURITY_GROUP_IDs} \
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

