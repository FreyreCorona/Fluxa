#!/usr/bin/env bash
set -euo pipefail

source ./lib/common.sh
source ./lib/packages.sh
source ./lib/filesystem.sh
source ./lib/firewall.sh
source ./lib/docker.sh

log "Installing base packages"
install_base_packages

log "Creating filesystem structure"
create_base_fs

log "Configuring firewall"
configure_firewall_internal

log "Installing Docker"
install_docker

log "Worker node bootstrap complete"
