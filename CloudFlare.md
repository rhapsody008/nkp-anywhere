# Cloudflare Local Tunnel with NKP

## Overview

This document covers setting up a Cloudflare tunnel to expose an NKP (Nutanix Kubernetes Platform) management cluster over a public DNS name, and issuing a trusted TLS certificate for that hostname so that management-to-workload cluster communication is secured end-to-end.

**High-level flow:**
1. Create a Cloudflare tunnel pointing to the Traefik ingress of the Kommander UI.
2. Issue a publicly-trusted certificate for the Cloudflare DNS name via Let's Encrypt (DNS-01 challenge).
3. Bootstrap the NKP management cluster using that certificate.

**Prerequisites:**
- A Cloudflare account with a registered domain (e.g. `yolocal.cloud`).
- `cloudflared` CLI installed on the bastion host.
- `certbot` accessible on the bastion host (installed in the next section).
- Sufficient Cloudflare API token permissions: **Zone → DNS → Edit** and **Zone → Zone → Read** for the target zone.

```
Install cloudflared CLI:

# Add cloudflare gpg key
sudo mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

# Add this repo to your apt repositories
# Stable
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared noble main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
# Nightly
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://next.pkg.cloudflare.com/cloudflared noble main' | sudo tee /etc/apt/sources.list.d/cloudflared.list

# install cloudflared
sudo apt-get update && sudo apt-get install cloudflared

```


---

## 1. Set Up `cloudflared`

> **One-time setup:** Steps 1.1–1.3 only need to be performed once. The output artifacts — `~/.cloudflared/<tunnel-id>.json` (tunnel credentials) and `~/.cloudflared/config.yml` — are portable. Once those two files exist on any machine, the tunnel can be started immediately from step 1.5 without repeating the setup steps.

### 1.1 Authenticate

Log in to Cloudflare from the bastion host. This opens a browser URL; complete the OAuth flow to generate a certificate at `~/.cloudflared/cert.pem`.

```bash
cloudflared tunnel login
```

### 1.2 Create the Tunnel

Create a named tunnel. Cloudflare generates a tunnel UUID and writes credentials to `~/.cloudflared/<tunnel-id>.json`.

```bash
cloudflared tunnel create zy
```

### 1.3 Route DNS to the Tunnel

Create a CNAME record in Cloudflare DNS mapping the public hostname to the tunnel's `.cfargotunnel.com` address.

```bash
cloudflared tunnel route dns zy nkp.yolocal.cloud
```

### 1.4 Write the Tunnel Config

Create `~/.cloudflared/config.yml`. The `credentials-file` path comes from the JSON file written by `cloudflared tunnel create` in step 1.2. The `service` URL should point to Traefik's cluster-internal or load-balancer address.

```bash
vi ~/.cloudflared/config.yml
```

Sample `config.yml`:

```yaml
tunnel: zy
credentials-file: /home/ntnx-user/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: nkp.yolocal.cloud
    service: https://<traefik-loadbalancer-ip>
    originRequest:
      noTLSVerify: false
  - service: http_status:404
```

> Replace `<tunnel-id>` with the UUID printed by `cloudflared tunnel create`, and `<traefik-loadbalancer-ip>` with the external IP of the `kommander-traefik` LoadBalancer service.

### 1.5 Start the Tunnel

Run the tunnel in the background, or configure it as a systemd service for persistence across reboots.

```bash
cloudflared tunnel run zy &
```

or consider register the tunnel process as a Systemd service.

---

## 2. Create NKP Cluster with Signed Certs

### 2.1 Install certbot and Generate Certs

Install certbot with the Cloudflare DNS plugin, then use DNS-01 challenge to issue a Let's Encrypt certificate. DNS-01 does not require the host to be publicly reachable on port 80/443 — certbot creates a temporary TXT record in Cloudflare to prove domain ownership.

```bash
sudo apt-get install -y certbot python3-certbot-dns-cloudflare

# Working directory for cert files
mkdir -p ~/nkp-certs && cd ~/nkp-certs

# Write Cloudflare API token credentials file (mode 600 required by certbot)
install -m 600 /dev/stdin ~/nkp-certs/cf-dns.ini <<'EOF'
dns_cloudflare_api_token = <CF_API_TOKEN>
EOF

sudo certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials ~/nkp-certs/cf-dns.ini \
  -d nkp.yolocal.cloud --email yi.zhou@nutanix.com --agree-tos --non-interactive

# Copy the issued certs out of /etc/letsencrypt (dereference symlinks with -L)
sudo cp -L /etc/letsencrypt/live/nkp.yolocal.cloud/fullchain.pem .
sudo cp -L /etc/letsencrypt/live/nkp.yolocal.cloud/privkey.pem .
sudo chown $USER:$USER fullchain.pem privkey.pem
chmod 600 privkey.pem

# Download the ISRG Root X1 CA used by Let's Encrypt
curl -sSL https://letsencrypt.org/certs/isrgrootx1.pem -o isrg-root-x1.pem
```

> Replace `<CF_API_TOKEN>` with a Cloudflare API token scoped to **Zone → DNS → Edit** on `yolocal.cloud`.

After this step `~/nkp-certs/` should contain: `fullchain.pem`, `privkey.pem`, `isrg-root-x1.pem`.

### 2.2 Create Cluster with Ingress Certs

Pass the certificate paths to `nkp create cluster`. These flags configure Traefik to serve the signed cert and set the cluster's public hostname:

```bash
nkp create cluster nutanix \
  ... \
  --cluster-hostname="nkp.yolocal.cloud" \
  --ingress-certificate=/home/ntnx-user/nkp-certs/fullchain.pem \
  --ingress-private-key=/home/ntnx-user/nkp-certs/privkey.pem \
  --ingress-ca=/home/ntnx-user/nkp-certs/isrg-root-x1.pem
```

### 2.3 Patch Thanos-Query configMap after Cluster Creation (Optional)

Possibly caused by ingress conflict. Without this patch, OpenCost will fail to reach the metrics backend.

```bash
INGRESS_IP=$(kubectl -n kommander get svc kommander-traefik \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

kubectl -n kommander create configmap kommander-thanos-query-stores \
  --from-literal=stores.yaml="- targets:
  - ${INGRESS_IP}:443
" --dry-run=client -o yaml | kubectl apply -f -
```

---

## Appendix: Automated Certificate Renewal via cert-manager

Instead of relying on the bastion `certbot` (The cert we created only last for 90 days), cert-manager (already running in NKP) can take over the full certificate lifecycle: initial issuance, rotation ~30 days before expiry, and secret hot-reload into Traefik — all without manual intervention.

### Step 1 — Create the Cloudflare API Token Secret

The `ClusterIssuer` resolves its `apiTokenSecretRef` in cert-manager's **own namespace** (`cert-manager`), not in `kommander`. Use a token scoped to **Zone → DNS → Edit** and **Zone → Zone → Read** on `yolocal.cloud`.

```bash
kubectl -n cert-manager create secret generic cloudflare-api-token \
  --from-literal=api-token=<CF_TOKEN>
```

### Step 2 — Create the ClusterIssuer

Save as `letsencrypt-dns01-clusterissuer.yaml` and apply it. This tells cert-manager to use Let's Encrypt's ACME server with Cloudflare DNS-01 for challenge resolution.

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-dns01
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: yi.zhou@nutanix.com
    privateKeySecretRef:
      name: letsencrypt-dns01-account
    solvers:
      - dns01:
          cloudflare:
            apiTokenSecretRef:
              name: cloudflare-api-token
              key: api-token
```

### Step 3 — Create the Certificate Resource

Save as `kommander-traefik-cert.yaml`. The `secretName` must exactly match the secret name that Traefik is configured to serve — cert-manager will overwrite it when the cert is issued or renewed.

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: kommander-traefik-tls
  namespace: kommander
spec:
  secretName: kommander-traefik-tls
  commonName: nkp.yolocal.cloud
  dnsNames:
    - nkp.yolocal.cloud
  issuerRef:
    name: letsencrypt-dns01
    kind: ClusterIssuer
  duration: 2160h     # 90 days
  renewBefore: 720h   # renew 30 days before expiry
```

### Step 4 — Apply and Watch

```bash
kubectl apply -f letsencrypt-dns01-clusterissuer.yaml
kubectl apply -f kommander-traefik-cert.yaml

kubectl get clusterissuer letsencrypt-dns01 -o wide           # expect READY=True
kubectl -n kommander get certificate kommander-traefik-tls -w  # expect READY=True

# If issuance stalls, inspect the ACME order/challenge chain:
kubectl -n kommander describe certificate,certificaterequest,order,challenge | tail -40
```

Once issued, cert-manager overwrites `kommander-traefik-tls` with the new cert. Traefik watches TLS secrets and hot-reloads — no pod restart needed.

### Step 5 — Verify the Live Cert

```bash
echo | openssl s_client -connect nkp.yolocal.cloud:443 -servername nkp.yolocal.cloud 2>/dev/null \
  | openssl x509 -noout -issuer -dates

kubectl -n kommander get certificate kommander-traefik-tls \
  -o jsonpath='{.status.notAfter}{"  renew at: "}{.status.renewalTime}{"\n"}'
```

Renewal is fully automatic from here — cert-manager re-runs DNS-01 ~30 days before expiry and rewrites the secret.

### Step 6 — Retire the Bastion certbot

Remove the bastion-managed cert so two systems are not racing to manage the same certificate:

```bash
sudo certbot delete --cert-name nkp.yolocal.cloud
```
