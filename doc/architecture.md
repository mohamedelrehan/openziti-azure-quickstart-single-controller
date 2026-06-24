# Architecture

This QuickStart deploys a non-HA OpenZiti environment on Azure.

## Components

- One Controller VM running OpenZiti Controller and ZAC
- Two Edge Router VMs for OpenZiti edge/fabric routing
- NGINX reverse proxy for HTTPS browser access to ZAC
- Optional Let's Encrypt certificate automation
- Azure VNet with separate control and router subnets

## Intended Use

This edition is suitable for labs, pilots, demos, and small environments. It is not a controller HA deployment.
