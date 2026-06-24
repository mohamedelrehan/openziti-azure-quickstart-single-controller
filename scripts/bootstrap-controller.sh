#!/usr/bin/env bash
set -Eeuo pipefail

# OpenZiti V3 Azure customer-ready bootstrap.
#
# Goals:
# - Azure ARM deployment should succeed if VM provisioning succeeds and the installer runs.
# - Operational health is written to /opt/openziti-quickstart/bootstrap-status.txt.
# - OpenZiti controller installation does not wait for DNS propagation.
# - DNS is only required for NGINX + Lets Encrypt.
# - If cert setup is delayed, controller remains available locally and helper scripts are created.
# - Certbot timer and dry-run are validated when certificate setup succeeds.

exec > >(tee -a /var/log/openziti-quickstart-bootstrap.log) 2>&1

AZURE_FQDN="${1:-}"
ZITI_USER="${2:-admin}"
ZITI_PWD_B64="${3:-}"
LE_EMAIL="${4:-}"
INSTALL_NGINX_LE="${5:-true}"
RUN_APT_UPGRADE="${6:-true}"
REPO_RAW_BASE_URL="${7:-https://raw.githubusercontent.com/mohamedelrehan/Ziti-V3/main}"

BOOTSTRAP_STATUS="success"
CERT_STATUS="not_requested"
CONTROLLER_STATUS="unknown"
NGINX_STATUS="unknown"

log() { printf '\n[INFO] %s\n' "$*"; }
warn() { printf '\n[WARN] %s\n' "$*" >&2; }
err() { printf '\n[ERROR] %s\n' "$*" >&2; }

set_status_warning() {
  if [[ "$BOOTSTRAP_STATUS" == "success" ]]; then
    BOOTSTRAP_STATUS="warning"
  fi
  warn "$*"
}

write_status() {
  mkdir -p /opt/openziti-quickstart
  cat > /opt/openziti-quickstart/bootstrap-status.txt <<EOF_STATUS
status=${BOOTSTRAP_STATUS}
controller_status=${CONTROLLER_STATUS}
nginx_status=${NGINX_STATUS}
certificate_status=${CERT_STATUS}
finished_at=$(date -Is)
fqdn=${AZURE_FQDN}
browser_url=https://${AZURE_FQDN}/zac/
direct_controller_url=https://${AZURE_FQDN}:1280/zac/
log=/var/log/openziti-quickstart-bootstrap.log
health_check=/opt/openziti-quickstart/check-openziti-quickstart.sh
rerun_cert=/opt/openziti-quickstart/run-nginx-letsencrypt-later.sh
EOF_STATUS
}

finish_for_azure() {
  write_status || true
  log "Bootstrap status: ${BOOTSTRAP_STATUS}"
  log "Controller status: ${CONTROLLER_STATUS}"
  log "NGINX status: ${NGINX_STATUS}"
  log "Certificate status: ${CERT_STATUS}"
  log "Bootstrap finished at $(date -Is)"
  log "Returning success to Azure Custom Script Extension. Use /opt/openziti-quickstart/bootstrap-status.txt for operational status."
  exit 0
}
trap finish_for_azure EXIT

dns_points_to_this_vm() {
  local fqdn="$1"
  local dns_ip public_ip

  dns_ip="$(getent ahostsv4 "$fqdn" | awk '{print $1}' | head -n1 || true)"
  public_ip="$(curl -4fsS https://api.ipify.org || true)"

  log "DNS check: ${fqdn}=${dns_ip:-unresolved}, vm_public_ip=${public_ip:-unknown}"

  [[ -n "$dns_ip" && -n "$public_ip" && "$dns_ip" == "$public_ip" ]]
}

wait_for_dns_for_cert() {
  local fqdn="$1"
  local attempts="${2:-30}"
  local sleep_seconds="${3:-20}"

  log "Waiting for DNS before Lets Encrypt: ${fqdn}"

  for i in $(seq 1 "$attempts"); do
    if dns_points_to_this_vm "$fqdn"; then
      log "DNS is ready for Lets Encrypt."
      return 0
    fi

    warn "DNS not ready for certificate yet: ${fqdn} attempt ${i}/${attempts}"
    sleep "$sleep_seconds"
  done

  return 1
}

write_helpers() {
  mkdir -p /opt/openziti-quickstart

  cat > /opt/openziti-quickstart/run-nginx-letsencrypt-later.sh <<EOF_LATER
#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/openziti-quickstart
sudo DOMAIN_NAME="${AZURE_FQDN}" ADMIN_EMAIL="${LE_EMAIL}" ./install-nginx-letsencrypt.sh
sudo systemctl enable certbot.timer 2>/dev/null || true
sudo systemctl start certbot.timer 2>/dev/null || true
sudo certbot renew --dry-run
EOF_LATER
  chmod +x /opt/openziti-quickstart/run-nginx-letsencrypt-later.sh

  cat > /opt/openziti-quickstart/check-openziti-quickstart.sh <<EOF_CHECK
#!/usr/bin/env bash
set -Eeuo pipefail

FQDN="${AZURE_FQDN}"

echo "=== Bootstrap status ==="
cat /opt/openziti-quickstart/bootstrap-status.txt 2>/dev/null || true
echo

echo "=== OpenZiti controller service ==="
sudo systemctl status ziti-controller --no-pager -l || true
echo

echo "=== NGINX service ==="
sudo systemctl status nginx --no-pager -l || true
echo

echo "=== Listening ports ==="
sudo ss -tulpn | egrep '1280|443|80' || true
echo

echo "=== Local controller/ZAC ==="
curl -kI https://127.0.0.1:1280/zac/ || true
echo

echo "=== Public browser ZAC ==="
curl -I https://\${FQDN}/zac/ || true
echo

echo "=== ZAC static assets ==="
curl -I https://\${FQDN}/assets/fonts/icomoon.woff2 || true
curl -I https://\${FQDN}/assets/animations/Loader.json || true
curl -I https://\${FQDN}/assets/svgs/ziti-logo.svg || true
echo

echo "=== Certificate ==="
sudo certbot certificates 2>/dev/null || true
echo

echo "=== Certbot timer ==="
systemctl list-timers --all | grep -E 'certbot|snap.certbot' || true
EOF_CHECK
  chmod +x /opt/openziti-quickstart/check-openziti-quickstart.sh
}

main() {
  log "Starting OpenZiti V3 bootstrap at $(date -Is)"
  log "Azure FQDN: ${AZURE_FQDN}"
  log "Repo raw base URL: ${REPO_RAW_BASE_URL}"
  log "Install NGINX and Lets Encrypt: ${INSTALL_NGINX_LE}"
  log "Run apt upgrade: ${RUN_APT_UPGRADE}"

  if [[ -z "$AZURE_FQDN" ]]; then
    set_status_warning "Azure FQDN argument is empty."
    return 0
  fi

  if [[ -z "$ZITI_PWD_B64" ]]; then
    set_status_warning "OpenZiti password argument is empty."
    return 0
  fi

  # Decode password into a root-only temp file so it never appears in the log.
  local pwd_file
  pwd_file="$(mktemp /tmp/.ziti-pwd.XXXXXX)"
  chmod 600 "${pwd_file}"
  printf "%s" "${ZITI_PWD_B64}" | base64 -d 2>/dev/null > "${pwd_file}" || true
  ZITI_PWD_B64=""  # scrub B64 from memory immediately
  unset ZITI_PWD_B64

  if [[ ! -s "${pwd_file}" ]]; then
    rm -f "${pwd_file}"
    set_status_warning "Could not decode OpenZiti password."
    return 0
  fi

  mkdir -p /opt/openziti-quickstart
  cd /opt/openziti-quickstart

  log "Installing base tools"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates jq dnsutils

  log "Downloading OpenZiti installer scripts"
  if ! curl -fsSL "${REPO_RAW_BASE_URL}/scripts/install-controller-zac.sh" -o install-controller-zac.sh; then
    rm -f "${pwd_file}"
    set_status_warning "Failed to download install-controller-zac.sh"
    return 0
  fi

  if ! curl -fsSL "${REPO_RAW_BASE_URL}/scripts/install-nginx-letsencrypt.sh" -o install-nginx-letsencrypt.sh; then
    rm -f "${pwd_file}"
    set_status_warning "Failed to download install-nginx-letsencrypt.sh"
    return 0
  fi

  chmod +x install-controller-zac.sh
  chmod +x install-nginx-letsencrypt.sh

  write_helpers

  log "Installing OpenZiti controller immediately. DNS propagation is not required for this step."

  # Pass password via subshell read from file so it never appears in process list or log.
  if ZITI_DNS="${AZURE_FQDN}" \
      ZITI_USER="${ZITI_USER}" \
      ZITI_PWD="$(cat "${pwd_file}")" \
      RUN_APT_UPGRADE="${RUN_APT_UPGRADE}" \
      SKIP_DNS_IP_MATCH="true" \
      ./install-controller-zac.sh; then
    log "OpenZiti installer completed."
  else
    set_status_warning "OpenZiti installer returned non-zero. Check /var/log/openziti-quickstart-bootstrap.log"
    CONTROLLER_STATUS="install_failed"
    rm -f "${pwd_file}"
    return 0
  fi

  rm -f "${pwd_file}" 

  if systemctl is-active --quiet ziti-controller && curl -kfsS https://127.0.0.1:1280/zac/ >/dev/null; then
    CONTROLLER_STATUS="running"
    log "OpenZiti controller and local ZAC are healthy."
  else
    CONTROLLER_STATUS="unhealthy"
    set_status_warning "OpenZiti controller or local ZAC is not healthy."
  fi

  if [[ "${INSTALL_NGINX_LE}" == "true" ]]; then
    CERT_STATUS="pending_dns"
    log "NGINX and Lets Encrypt requested."

    if wait_for_dns_for_cert "${AZURE_FQDN}" 30 20; then
      log "Installing NGINX, Lets Encrypt certificate, and ZAC assets fix."
      if DOMAIN_NAME="${AZURE_FQDN}" ADMIN_EMAIL="${LE_EMAIL}" ./install-nginx-letsencrypt.sh; then
        NGINX_STATUS="installed"
        CERT_STATUS="issued"

        log "Enabling and validating Certbot renewal timer."
        systemctl enable certbot.timer 2>/dev/null || true
        systemctl start certbot.timer 2>/dev/null || true

        if certbot renew --dry-run; then
          CERT_STATUS="issued_renewal_verified"
          log "Certificate renewal dry-run succeeded."
        else
          CERT_STATUS="issued_renewal_warning"
          set_status_warning "Certificate issued, but certbot renew --dry-run returned non-zero."
        fi
      else
        NGINX_STATUS="install_warning"
        CERT_STATUS="issue_warning"
        set_status_warning "NGINX/Lets Encrypt script returned non-zero. Run: sudo /opt/openziti-quickstart/run-nginx-letsencrypt-later.sh"
      fi
    else
      NGINX_STATUS="not_installed_dns_pending"
      CERT_STATUS="dns_pending"
      BOOTSTRAP_STATUS="controller_ok_cert_pending"
      warn "DNS was not ready for Lets Encrypt within timeout."
      warn "OpenZiti controller should still be running locally and on port 1280 if NSG allows."
      warn "After DNS resolves, run: sudo /opt/openziti-quickstart/run-nginx-letsencrypt-later.sh"
    fi
  else
    NGINX_STATUS="skipped"
    CERT_STATUS="skipped"
    warn "NGINX and Lets Encrypt skipped by parameter."
  fi

  log "Final health summary"
  /opt/openziti-quickstart/check-openziti-quickstart.sh || true
}

main "$@"
