# OpenZiti Azure QuickStart — Single Controller Edition

Deploy a low-cost OpenZiti Zero Trust Network on Microsoft Azure using an ARM template.

This repository deploys **one OpenZiti Controller with ZAC** and **two OpenZiti Edge Routers**. It is designed for evaluation, labs, pilots, demos, and small non-HA environments.

> This is the **Single Controller Edition**. It is **not high availability**. For production HA deployments, use the separate **OpenZiti Azure QuickStart — HA Edition**.

## What It Installs

- 1 OpenZiti Controller VM
- OpenZiti Administration Console (ZAC)
- 2 OpenZiti Edge Router VMs
- NGINX reverse proxy for browser access to ZAC
- Optional Let's Encrypt certificate automation using Certbot
- Azure Virtual Network
- Control subnet and router subnet
- Network Security Groups
- Public IP addresses and DNS labels
- Bootstrap scripts for controller and router enrollment
- Health-check and validation scripts

## Default Azure Sizing

The default VM size is intentionally small to keep the deployment low-cost:

| Component | Default Size |
|---|---:|
| Controller + ZAC | Standard_B1s |
| Edge Router 1 | Standard_B1s |
| Edge Router 2 | Standard_B1s |

You can change the VM size during deployment if you need more capacity.

## Architecture

```text
Internet
   |
   | HTTPS 443
   v
+-------------------------------+
| Controller VM                 |
| - NGINX                       |
| - Let's Encrypt / Certbot     |
| - OpenZiti Controller         |
| - Ziti Administration Console |
+-------------------------------+
        |                |
        | OpenZiti       | OpenZiti
        v                v
+----------------+  +----------------+
| Edge Router 01 |  | Edge Router 02 |
+----------------+  +----------------+
```

## Deploy to Azure

Update the GitHub repository URL after publishing, then use this button:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/REPLACE_WITH_RAW_ENCODED_AZUREDEPLOY_JSON_URL)

Example raw template URL format:

```text
https://raw.githubusercontent.com/<owner>/openziti-azure-quickstart-single-controller/main/azuredeploy.json
```

## Repository Structure

```text
openziti-azure-quickstart-single-controller/
├── README.md
├── azuredeploy.json
├── azuredeploy.parameters.example.json
├── scripts/
│   ├── bootstrap-controller.sh
│   ├── bootstrap-router.sh
│   ├── install-controller-zac.sh
│   └── install-nginx-letsencrypt.sh
└── docs/
    ├── architecture.md
    ├── validation.md
    ├── troubleshooting.md
    └── controller-nginx-zac-detailed.md
```

## Prerequisites

Before deploying, make sure you have:

- An Azure subscription
- Permission to create VMs, public IPs, NICs, NSGs, and VNets
- Quota for 3 × Standard_B1s VMs
- Quota for 3 × Standard Public IP addresses
- A valid email address for Let's Encrypt if HTTPS automation is enabled

## Important Parameters

| Parameter | Purpose | Default |
|---|---|---|
| `deploymentPrefix` | Prefix used for Azure resource names | `openziti-quickstart` |
| `vmSizeController` | Controller VM size | `Standard_B1s` |
| `vmSizeRouter` | Router VM size | `Standard_B1s` |
| `dnsLabelPrefix` | Azure public DNS label prefix | Required |
| `openZitiAdminUser` | OpenZiti admin username | `admin` |
| `openZitiAdminPassword` | OpenZiti admin password | Required |
| `letsEncryptEmail` | Email for Certbot / Let's Encrypt | Required |
| `installNginxLetsEncrypt` | Install NGINX and Let's Encrypt | `true` |
| `repoRawBaseUrl` | Raw GitHub base URL for scripts | This repo |

## Post-Deployment Validation

On the controller VM:

```bash
sudo /opt/openziti-quickstart/check-openziti-quickstart.sh
cat /opt/openziti-quickstart/bootstrap-status.txt
```

On each router VM:

```bash
sudo /opt/openziti-quickstart-router/check-router.sh
cat /opt/openziti-quickstart-router/router-status.txt
```

Access ZAC:

```text
https://<controller-dns-name>/zac/
```

Native controller API:

```text
https://<controller-dns-name>:1280
```

## Security Notes

For public deployment, review these settings before use:

- Restrict SSH source IP using `adminSourceAddressPrefix`
- Use strong admin passwords
- Rotate credentials after initial testing
- Consider Azure Bastion instead of public SSH
- Store secrets in Azure Key Vault for future production versions
- Use the HA Edition for production-grade controller resilience

## Single Controller Limitations

This edition does not provide controller high availability.

If the controller VM is unavailable:

- ZAC is unavailable
- OpenZiti management API is unavailable
- New enrollments and policy changes are unavailable
- Existing data-plane behavior depends on current sessions and router state

For resilient production deployments, use the HA Edition.

## Disclaimer

This is a community QuickStart project and is not an official Microsoft or OpenZiti product.
