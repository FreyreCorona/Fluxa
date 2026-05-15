#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[+] $1"
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root or with sudo"
    exit 1
  fi
}
