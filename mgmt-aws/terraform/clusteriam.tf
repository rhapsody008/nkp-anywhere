resource "aws_kms_key" "capa_kms_key" {
  description             = "KMS key for Cluster API Provider AWS"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  # Default policy to allow the root account to manage this key
  # This is required so you don't lock yourself out of the key
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "capa_kms_alias" {
  name          = "alias/capa-cluster-api-key"
  target_key_id = aws_kms_key.capa_kms_key.key_id
}

# -------------------------------------------------------------------
# 1. IAM ROLES
# -------------------------------------------------------------------

# Role: Control Plane
resource "aws_iam_role" "control_plane_role" {
  name = "control-plane.cluster-api-provider-aws.sigs.k8s.io"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Role: Nodes (Workers)
resource "aws_iam_role" "nodes_role" {
  name = "nodes.cluster-api-provider-aws.sigs.k8s.io"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# -------------------------------------------------------------------
# 2. IAM POLICIES
# -------------------------------------------------------------------

# Policy 1: Cloud Provider Control Plane
resource "aws_iam_policy" "cloud_provider_control_plane" {
  name        = "control-plane.cluster-api-provider-aws.sigs.k8s.io"
  description = "For the Kubernetes Cloud Provider AWS Control Plane"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Resource = "*"
      Action = [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeTags",
        "ec2:AssignIpv6Addresses",
        "ec2:DescribeInstances",
        "ec2:DescribeImages",
        "ec2:DescribeRegions",
        "ec2:DescribeRouteTables",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSubnets",
        "ec2:DescribeVolumes",
        "ec2:CreateSecurityGroup",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyVolume",
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteVolume",
        "ec2:DetachVolume",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:DescribeVpcs",
        "elasticloadbalancing:AddTags",
        "elasticloadbalancing:AttachLoadBalancerToSubnets",
        "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
        "elasticloadbalancing:SetSecurityGroups",
        "elasticloadbalancing:CreateLoadBalancer",
        "elasticloadbalancing:CreateLoadBalancerPolicy",
        "elasticloadbalancing:CreateLoadBalancerListeners",
        "elasticloadbalancing:ConfigureHealthCheck",
        "elasticloadbalancing:DeleteLoadBalancer",
        "elasticloadbalancing:DeleteLoadBalancerListeners",
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeLoadBalancerAttributes",
        "elasticloadbalancing:DetachLoadBalancerFromSubnets",
        "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
        "elasticloadbalancing:ModifyLoadBalancerAttributes",
        "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
        "elasticloadbalancing:SetLoadBalancerPoliciesForBackendServer",
        "elasticloadbalancing:CreateListener",
        "elasticloadbalancing:CreateTargetGroup",
        "elasticloadbalancing:DeleteListener",
        "elasticloadbalancing:DeleteTargetGroup",
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:DescribeListeners",
        "elasticloadbalancing:DescribeLoadBalancerPolicies",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:ModifyListener",
        "elasticloadbalancing:ModifyTargetGroup",
        "elasticloadbalancing:RegisterTargets",
        "elasticloadbalancing:SetLoadBalancerPoliciesOfListener",
        "iam:CreateServiceLinkedRole",
        "kms:DescribeKey"
      ]
    }]
  })
}

# Policy 2: Cloud Provider Nodes
resource "aws_iam_policy" "cloud_provider_nodes" {
  name        = "nodes.cluster-api-provider-aws.sigs.k8s.io"
  description = "For the Kubernetes Cloud Provider AWS nodes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "ec2:AssignIpv6Addresses",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "ec2:CreateTags",
          "ec2:DescribeTags",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstanceTypes",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:BatchGetImage"
        ]
      },
      {
        Effect   = "Allow"
        Resource = "arn:*:secretsmanager:*:*:secret:aws.cluster.x-k8s.io/*"
        Action = [
          "secretsmanager:DeleteSecret",
          "secretsmanager:GetSecretValue"
        ]
      },
      {
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "s3:GetEncryptionConfiguration"
        ]
      }
    ]
  })
}

# Policy 3: Controllers (Merged with your S3, EC2 Endpoints, and KMS requests)
resource "aws_iam_policy" "controllers_policy" {
  name        = "controllers.cluster-api-provider-aws.sigs.k8s.io"
  description = "For the Kubernetes Cluster API Provider AWS Controllers"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "ec2:DescribeIpamPools",
          "ec2:AllocateIpamPoolCidr",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:AllocateAddress",
          "ec2:AssignIpv6Addresses",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses",
          "ec2:AssociateRouteTable",
          "ec2:AssociateVpcCidrBlock",
          "ec2:AttachInternetGateway",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateCarrierGateway",
          "ec2:CreateInternetGateway",
          "ec2:CreateEgressOnlyInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:CreateNetworkInterface",
          "ec2:CreateRoute",
          "ec2:CreateRouteTable",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSubnet",
          "ec2:CreateTags",
          "ec2:CreateVpc",
          "ec2:CreateVpcEndpoint",
          "ec2:DisassociateVpcCidrBlock",
          "ec2:ModifyVpcAttribute",
          "ec2:ModifyVpcEndpoint",
          "ec2:DeleteCarrierGateway",
          "ec2:DeleteInternetGateway",
          "ec2:DeleteEgressOnlyInternetGateway",
          "ec2:DeleteNatGateway",
          "ec2:DeleteRouteTable",
          "ec2:ReplaceRoute",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSubnet",
          "ec2:DeleteTags",
          "ec2:DeleteVpc",
          "ec2:DeleteVpcEndpoints",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeCarrierGateways",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeEgressOnlyInternetGateways",
          "ec2:DescribeImages",
          "ec2:DescribeNatGateways",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeNetworkInterfaceAttribute",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags",
          "ec2:DetachInternetGateway",
          "ec2:DisassociateRouteTable",
          "ec2:DisassociateAddress",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:ModifySubnetAttribute",
          "ec2:ReleaseAddress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:GetSecurityGroupsForVpc",
          "tag:GetResources",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:ConfigureHealthCheck",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:ApplySecurityGroupsToLoadBalancer",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:DeleteListener",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeInstanceRefreshes",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DeleteLaunchTemplate",
          "ec2:DeleteLaunchTemplateVersions",
          "ec2:DescribeKeyPairs",
          "ec2:ModifyInstanceMetadataOptions"
        ]
      },
      {
        Effect   = "Allow"
        Resource = "arn:*:autoscaling:*:*:autoScalingGroup:*:autoScalingGroupName/*"
        Action = [
          "autoscaling:CreateAutoScalingGroup", "autoscaling:UpdateAutoScalingGroup",
          "autoscaling:CreateOrUpdateTags", "autoscaling:StartInstanceRefresh",
          "autoscaling:DeleteAutoScalingGroup", "autoscaling:DeleteTags"
        ]
      },
      {
        Effect    = "Allow"
        Condition = { StringLike = { "iam:AWSServiceName" = "autoscaling.amazonaws.com" } }
        Resource  = "arn:*:iam::*:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
        Action    = "iam:CreateServiceLinkedRole"
      },
      {
        Effect    = "Allow"
        Condition = { StringLike = { "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com" } }
        Resource  = "arn:*:iam::*:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing"
        Action    = "iam:CreateServiceLinkedRole"
      },
      {
        Effect    = "Allow"
        Condition = { StringLike = { "iam:AWSServiceName" = "spot.amazonaws.com" } }
        Resource  = "arn:*:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot"
        Action    = "iam:CreateServiceLinkedRole"
      },
      {
        Effect   = "Allow"
        Resource = "arn:*:iam::*:role/*.cluster-api-provider-aws.sigs.k8s.io"
        Action   = "iam:PassRole"
      },
      {
        Effect   = "Allow"
        Resource = "arn:*:secretsmanager:*:*:secret:aws.cluster.x-k8s.io/*"
        Action   = ["secretsmanager:CreateSecret", "secretsmanager:DeleteSecret", "secretsmanager:TagResource"]
      },
      # --- S3 & EC2 Endpoint Permissions Added Here ---
      {
        Effect   = "Allow"
        Resource = "arn:*:s3:::cluster-api-provider-aws-*"
        Action = [
          "s3:CreateBucket", "s3:DeleteBucket", "s3:PutObject",
          "s3:DeleteObject", "s3:PutBucketPolicy", "s3:PutBucketTagging"
        ]
      },
      # --- KMS Permissions Added Here ---
      {
        Effect   = "Allow"
        Resource = "${aws_kms_key.capa_kms_key.arn}"
        Action = [
          "kms:CreateGrant", "kms:DescribeKey", "kms:Encrypt",
          "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*"
        ]
      }
    ]
  })
}

# -------------------------------------------------------------------
# 3. ATTACHMENTS (Linking Policies to Roles)
# -------------------------------------------------------------------

# A. Attach 'CloudProviderControlPlane' to ControlPlaneRole
resource "aws_iam_role_policy_attachment" "cp_policy_to_cp_role" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = aws_iam_policy.cloud_provider_control_plane.arn
}

# B. Attach 'CloudProviderNodes' to ControlPlaneRole (As defined in your CFN)
resource "aws_iam_role_policy_attachment" "nodes_policy_to_cp_role" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = aws_iam_policy.cloud_provider_nodes.arn
}

# C. Attach 'CloudProviderNodes' to NodesRole
resource "aws_iam_role_policy_attachment" "nodes_policy_to_nodes_role" {
  role       = aws_iam_role.nodes_role.name
  policy_arn = aws_iam_policy.cloud_provider_nodes.arn
}

# D. Attach 'Controllers' to ControlPlaneRole (As defined in your CFN)
resource "aws_iam_role_policy_attachment" "controllers_policy_to_cp_role" {
  role       = aws_iam_role.control_plane_role.name
  policy_arn = aws_iam_policy.controllers_policy.arn
}

# -------------------------------------------------------------------
# 4. INSTANCE PROFILES
# -------------------------------------------------------------------

resource "aws_iam_instance_profile" "control_plane_profile" {
  name = "control-plane.cluster-api-provider-aws.sigs.k8s.io"
  role = aws_iam_role.control_plane_role.name
}

resource "aws_iam_instance_profile" "nodes_profile" {
  name = "nodes.cluster-api-provider-aws.sigs.k8s.io"
  role = aws_iam_role.nodes_role.name
}
