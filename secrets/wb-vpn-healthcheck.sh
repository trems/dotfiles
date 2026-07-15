#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="/run/wb-vpn-health.lock"
STATE_DIR="/var/lib/wb-vpn-health"
LAST_RESTART_FILE="${STATE_DIR}/last_restart_epoch"
COOLDOWN_SEC=300
RETRY_COUNT=3
RETRY_SLEEP=5
DNS1="10.15.12.100"
DNS2="10.15.12.200"
TEST_DOMAIN="wb.ru"
TPM_LOG_LINES=80

mkdir -p "${STATE_DIR}"

log() {
  logger -t wb-vpn-health "$*"
  echo "$*"
}

is_healthy() {
  ip link show tun0 >/dev/null 2>&1 || return 1
  ip route get "${DNS1}" 2>/dev/null | grep -q "dev tun0" || return 1
  # DNS reachability through corp tunnel
  timeout 4 dig +time=2 +tries=1 @"${DNS1}" "${TEST_DOMAIN}" A >/dev/null 2>&1 && return 0
  timeout 4 dig +time=2 +tries=1 @"${DNS2}" "${TEST_DOMAIN}" A >/dev/null 2>&1 && return 0
  return 1
}

restart_allowed() {
  local now last=0
  now="$(date +%s)"
  if [[ -f "${LAST_RESTART_FILE}" ]]; then
    last="$(cat "${LAST_RESTART_FILE}" || echo 0)"
  fi
  (( now - last >= COOLDOWN_SEC ))
}

has_tpm_provider_failure() {
  journalctl -u wb_vpn --no-pager -n "${TPM_LOG_LINES}" 2>/dev/null |
    grep -Eq "failed to load provider 'tpm2'|init fail:name=tpm2|tcti:Function called in the wrong order|Esys_GetCapability"
}

recover_tpm_if_needed() {
  if ! has_tpm_provider_failure; then
    return 0
  fi

  log "TPM_RECOVERY_ATTEMPT tpm2-abrmd"
  systemctl restart tpm2-abrmd
}

(
  flock -n 9 || { log "HEALTH_SKIP lock_busy"; exit 0; }

  if is_healthy; then
    log "HEALTH_OK"
    exit 0
  fi

  log "HEALTH_BAD detected"
  # Keep endpoint mapping fresh before restart
  /usr/local/sbin/wb-vpn-refresh-endpoint.sh || log "REFRESH_WARN failed"

  if ! restart_allowed; then
    log "RESTART_SKIPPED cooldown_active"
    exit 1
  fi

  date +%s > "${LAST_RESTART_FILE}"
  recover_tpm_if_needed
  log "RESTART_ATTEMPT wb_vpn"
  systemctl restart wb_vpn

  for i in $(seq 1 "${RETRY_COUNT}"); do
    sleep "${RETRY_SLEEP}"
    if is_healthy; then
      log "RECOVERY_OK attempt=${i}"
      exit 0
    fi
  done

  log "RECOVERY_FAILED after_retries=${RETRY_COUNT}"
  exit 1
) 9>"${LOCK_FILE}"
