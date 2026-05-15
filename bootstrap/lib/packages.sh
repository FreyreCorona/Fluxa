#!/usr/bin/env bash

install_base_packages() {
  apt update
  apt upgrade -y

  apt install -y \
    curl \
    wget \
    git \
    jq \
    htop \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw
}
