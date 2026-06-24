# OpenZiti Azure QuickStart — Single Controller Edition

Deploy a production-ready **OpenZiti** environment on **Microsoft Azure** using a single-click ARM deployment.

This QuickStart deploys:
- 1 × OpenZiti Controller
- 2 × OpenZiti Edge Routers
- OpenZiti Administration Console (ZAC)
- NGINX Reverse Proxy
- Automatic Let's Encrypt HTTPS certificates

> **Note:** This repository provides the **Single Controller Edition** and is **not** a High Availability (HA) deployment.

## Deploy to Azure

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fmohamedelrehan%2Fopenziti-azure-quickstart-single-controller%2Fmain%2Fazuredeploy.json)

## Architecture

- 1 × OpenZiti Controller
- 2 × Edge Routers
- Azure Virtual Network
- NGINX Reverse Proxy
- Let's Encrypt
- Azure Network Security Groups

## Default VM Size

- Standard_B1s

## Repository Structure

```
README.md
azuredeploy.json
azuredeploy.parameters.example.json
docs/
scripts/
```

## Requirements

- Azure Subscription
- Contributor permissions
- Public DNS name
- Email address for Let's Encrypt

## License

See the LICENSE file.
