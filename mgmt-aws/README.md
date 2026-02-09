# Basic Info

## Notes

AWS Network Infra: need at least 1 public subnet w/ IGW & 1 private subnet w/ NATGW

private IP controllable by NKP?? 

# Steps

1. Terraform apply for infra provisioning, get VPC ID and Subnet IDs from output

2. If AMI is not yet available, build the image
```
cd mynkp
tar -xzvf kib.tar.gz -C kib && cd kib
./konvoy-image create-package-bundle --os ubuntu-22.04 --output-directory=artifacts
./konvoy-image build aws --region ap-southeast-1 images/ami/ubuntu-2204.yaml
```
3. Get the AMI id from generated manifest.json

4. Put VPC ID, Subnet IDs, AMD ID into create.sh

5. Copy & Run create.sh

6. `cat ~/mynkp/nkp.conf >> ~/.kube/config`

7. Copy kommander.yaml & Install Kommander ( AWS creds put in kommander.yaml if needed )
```
nkp install kommander --installer-config kommander.yaml
```

8. Check installation status & get Kommander creds
```
kubectl -n kommander wait --for condition=Ready helmreleases --all --timeout 15m
nkp open dashboard
kubectl -n kommander get secret dkp-credentials -o go-template='Username: {{.data.username|base64decode}}{{ "\n"}}Password: {{.data.password|base64decode}}{{ "\n"}}'
kubectl -n kommander get svc kommander-traefik -o go-template='https://{{with index .status.loadBalancer.ingress 0}}{{or .hostname .ip}}{{end}}/dkp/kommander/dashboard{{ "\n"}}'
```

9. Install metrics-server
```
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

# Destroy Steps
***!!! Delete NKP Cluster before Terraform Destroy!!!***

1. delete cluster from bastion
```
nkp delete cluster --cluster-name=nkp --self-managed --kubeconfig=<KUBECONFIG> 
```

2. Terraform Destroy to destroy bastion & network infra