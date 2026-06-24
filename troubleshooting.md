# Troubleshooting

## Controller bootstrap log

```bash
sudo tail -n 200 /var/log/openziti-quickstart-bootstrap.log
```

## Router bootstrap log

```bash
sudo tail -n 200 /var/log/openziti-quickstart-router-bootstrap.log
```

## Re-run NGINX and Let's Encrypt after DNS is ready

```bash
sudo /opt/openziti-quickstart/run-nginx-letsencrypt-later.sh
```

## Check DNS

```bash
nslookup <controller-fqdn>
curl -I https://<controller-fqdn>/zac/
```
