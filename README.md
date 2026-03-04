# NKP Anywhere

Deployment-ready YAML manifests, Terraform configurations, and bash scripts for bootstrapping **Nutanix Kubernetes Platform (NKP)** clusters across multiple infrastructure platforms.

## Overview

This repository provides a reproducible, automation-first approach to deploying NKP management and workload clusters. All deployment scenarios follow an **air-gapped model** using local Harbor registries and pre-packaged image bundles, with infrastructure provisioned via **Terraform**.

## Repository Structure

```
nkp-anywhere/
├── mgmt-aws/          # NKP management cluster on AWS
│   ├── create.sh              # Cluster creation script
│   ├── kommander.yaml         # Kommander app catalog configuration
│   └── terraform/             # VPC, bastion, IAM, Route53
│
├── mgmt-nci/          # NKP management cluster on Nutanix infrastructure
│   ├── nkp-mgmt-create.sh     # Cluster creation script (air-gapped)
│   ├── harbor-install.sh      # Harbor registry installer
│   ├── bindsecret.yaml        # LDAP bind secret
│   ├── connector.yaml         # Dex LDAP connector
│   ├── group.yaml             # Virtual group mapping
│   ├── nkpmaster-role-binding.yaml  # RBAC role binding
│   └── terraform/             # Bastion, Harbor VM, network provisioning
│
├── wkld-nci/          # NKP workload cluster on Nutanix infrastructure
│   ├── DEPLOY.md              # Deployment sequence guide
│   ├── nkp-wkld-dry-run.sh    # Manifest generation (dry-run)
│   ├── workspace.yaml         # Kommander workspace
│   ├── project.yaml           # Kommander project
│   ├── nkpmaster-workspace-role-binding.yaml
│   └── manifest/              # Generated cluster manifests & secrets
│
└── misc-nci/          # Supporting resources (git-ignored)
    ├── certificates/          # TLS certs for Harbor registry
    └── *.tar.gz / *.tgz       # Air-gapped bundles & Harbor installer
```

## Deployment Scenarios

### 1. NKP on AWS (`mgmt-aws/`)

Deploys a self-managed NKP cluster on AWS with a bastion host as the control plane entry point.

**Infrastructure**: VPC with public/private subnets, NAT gateway, bastion EC2 instance, IAM roles, Route53 DNS.

**Workflow**:
1. `terraform apply` in `mgmt-aws/terraform/` to provision VPC, subnets, and bastion host
2. Build or obtain the NKP AMI (via KIB bundle)
3. Update `create.sh` with VPC/Subnet/AMI IDs, then execute on bastion to create the cluster
4. Apply `kommander.yaml` to install the management platform (Prometheus, Grafana, Velero, External DNS, etc.)

### 2. NKP on Nutanix Infrastructure — Management Cluster (`mgmt-nci/`)

Deploys a self-managed NKP management cluster on existing Nutanix infrastructure (Prism Central/Element), fully air-gapped.

**Infrastructure**: Bastion VM, Harbor registry VM, secondary VLAN subnet — all provisioned via Terraform against Nutanix APIs.

**Workflow**:
1. `terraform apply` in `mgmt-nci/terraform/` to provision bastion and Harbor VMs
2. Run `harbor-install.sh` on the Harbor VM to set up the local container registry
3. Execute `nkp-mgmt-create.sh` on bastion to create the management cluster (pushes image bundles to Harbor)
4. Configure LDAP authentication by applying manifests in order:
   `bindsecret.yaml` → `connector.yaml` → `group.yaml` → `nkpmaster-role-binding.yaml`

### 3. NKP on Nutanix Infrastructure — Workload Cluster (`wkld-nci/`)

Deploys managed workload clusters from the NCI management cluster.

**Workflow** (see [DEPLOY.md](wkld-nci/DEPLOY.md) for full sequence):
1. Apply `workspace.yaml` to create the Kommander workspace
2. Apply workspace-level RBAC
3. Run `nkp-wkld-dry-run.sh` to generate cluster manifests into `manifest/`
4. Apply all manifests (cluster topology + secrets)
5. Apply `project.yaml` and project-level RBAC

## Key Technologies

| Component | Details |
|-----------|---------|
| NKP | v2.16.1 / v2.17.0 |
| Kubernetes | v1.33.5 |
| Terraform | AWS provider v6.26.0, Nutanix provider v2.3.4 |
| Harbor | v2.14.2 (offline installer) |
| CNI | Cilium |
| Storage | Nutanix CSI (NCI), Rook Ceph (AWS) |
| Auth | Dex + LDAP/Active Directory |

## Prerequisites

- **Terraform** installed locally or on the bastion host
- **NKP CLI** (`nkp`) available (included in the air-gapped bundle)
- **Docker** on the bastion/Harbor host
- For Nutanix: existing Prism Central with credentials and network connectivity
- For AWS: AWS credentials with permissions for VPC, EC2, IAM, and Route53

## Notes

- The `misc-nci/` directory is git-ignored — it contains large binary bundles and TLS certificates that should not be committed.
- All scripts and manifests contain placeholder values (cluster names, IPs, credentials) that must be customized for your environment before use.
- Secrets in this repo use example/lab credentials. Replace them with your own before deploying to any environment.


## MISC

```
Manual command to install harbor:
sudo REGISTRY_FQDN=zy-registry.ntnxlab.local DOMAIN_NAME=ntnxlab.local ./harbor-install.sh
```

LDAP Basic Config Sequence:
`bindsecret.yaml >> connector.yaml >> group.yaml >> nkpmaster-role-binding.yaml`