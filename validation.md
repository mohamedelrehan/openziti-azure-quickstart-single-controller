# Validation

## Controller

```bash
sudo /opt/openziti-quickstart/check-openziti-quickstart.sh
cat /opt/openziti-quickstart/bootstrap-status.txt
systemctl status ziti-controller --no-pager
```

## Routers

```bash
sudo /opt/openziti-quickstart-router/check-router.sh
cat /opt/openziti-quickstart-router/router-status.txt
systemctl status ziti-router --no-pager
```

## ZAC

Open:

```text
https://<controller-fqdn>/zac/
```
