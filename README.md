# nkp-everywhere
NKP Bootstrap everywhere!

## Objective

- Automate the deployment of NKP fleet in possible ways, based on `Terraform`.
- Based on Air-gapped Deployment.

## Deployment Steps

### NKP Self-managed Cluster on Nutanix Infrastructure
```
Prerequisite: 
- Existing NCI with Prism Central up and running

Working Directory: ./mgmt-nci
```
1. Deploy Bastion & Harbor from `WORK_DIR/terraform`

```
Manual command to install harbor:
sudo REGISTRY_FQDN=zy-registry.ntnxlab.local DOMAIN_NAME=ntnxlab.local ./harbor-install.sh
```

LDAP Basic Config Sequence:
`bindsecret.yaml >> connector.yaml >> group.yaml >> nkpmaster-role-binding.yaml`