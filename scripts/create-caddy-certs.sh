#!/usr/bin/env bash
set -euo pipefail

# Creates certificates that match caddy/Caddyfile:
# - /etc/caddy/certs/ip.pem + ip-key.pem
# - /etc/caddy/certs/rpiai.local.pem + rpiai.local-key.pem

DOMAIN="rpiai.local"
CLEAN=false
IPS=()

usage() {
  cat <<'EOF'
Usage: ./scripts/create-caddy-certs.sh [options]

Options:
  --ip <address>      Add IP SAN for ip.pem (can be used multiple times)
  --domain <name>     Domain for domain cert (default: rpiai.local)
  --clean             Remove old *.pem files in caddy/certs before generating
  -h, --help          Show this help

Examples:
  ./scripts/create-caddy-certs.sh --ip 192.168.1.10 --ip 192.168.1.11
  ./scripts/create-caddy-certs.sh --clean
EOF
}

while (($# > 0)); do
  case "$1" in
    --ip)
      if (($# < 2)); then
        echo "Error: --ip requires a value" >&2
        exit 1
      fi
      IPS+=("$2")
      shift 2
      ;;
    --domain)
      if (($# < 2)); then
        echo "Error: --domain requires a value" >&2
        exit 1
      fi
      DOMAIN="$2"
      shift 2
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v mkcert >/dev/null 2>&1; then
  echo "Error: mkcert is not installed or not on PATH." >&2
  echo "Install mkcert first, then run this script again." >&2
  exit 1
fi

# Derive repo root from script location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CERT_DIR="${REPO_ROOT}/caddy/certs"

mkdir -p "${CERT_DIR}"

if [ "${CLEAN}" = true ]; then
  rm -f "${CERT_DIR}"/*.pem
fi

if ((${#IPS[@]} == 0)); then
  # Auto-detect IPv4 addresses when no IPs are passed.
  if command -v hostname >/dev/null 2>&1; then
    while read -r ip; do
      [ -n "${ip}" ] && IPS+=("${ip}")
    done < <(hostname -I 2>/dev/null | tr ' ' '\n' | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/')
  fi
fi

if ((${#IPS[@]} == 0)); then
  echo "Error: no IP addresses found. Pass one or more --ip values." >&2
  exit 1
fi

# Trust mkcert local CA on this host if not already installed.
mkcert -install >/dev/null

echo "Generating IP certificate: ${CERT_DIR}/ip.pem"
mkcert \
  -key-file "${CERT_DIR}/ip-key.pem" \
  -cert-file "${CERT_DIR}/ip.pem" \
  "${IPS[@]}"

echo "Generating domain certificate for ${DOMAIN}: ${CERT_DIR}/${DOMAIN}.pem"
mkcert \
  -key-file "${CERT_DIR}/${DOMAIN}-key.pem" \
  -cert-file "${CERT_DIR}/${DOMAIN}.pem" \
  "${DOMAIN}"

echo
echo "Done. Generated certificates:"
ls -l "${CERT_DIR}"/*.pem

echo
echo "Caddyfile expects these files:"
echo "- /etc/caddy/certs/ip.pem"
echo "- /etc/caddy/certs/ip-key.pem"
echo "- /etc/caddy/certs/${DOMAIN}.pem"
echo "- /etc/caddy/certs/${DOMAIN}-key.pem"
