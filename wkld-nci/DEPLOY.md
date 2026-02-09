# Deployment Sequence

1. Workspace: `workspace.yaml` - apply in mgmt cluster

2. Workspace RBAC: `nkpmaster-workspace-role-binding.yaml` - apply in mgmt cluster

3. Workload Cluster Dry Run: `nkp-wkld-dry-run.sh` --> `manifest/`

4. Workload Cluster: `All manifests in manifest/`

5. Project: `project.yaml` - apply in mgmt cluster

6. Project RBAC: `nkpmaster-role-binding.yaml` - apply in mgmt cluster