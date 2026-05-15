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
create_edge_dirs

log "Configuring firewall"
configure_firewall_edge

log "Installing Docker"
install_docker

log "Edge node bootstrap complete"
