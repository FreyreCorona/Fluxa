#!/usr/bin/env bash

configure_firewall_edge() {
  ufw default deny incoming
  ufw default allow outgoing

  ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp

  ufw --force enable
}

configure_firewall_internal() {
  ufw default deny incoming
  ufw default allow outgoing

  ufw allow 22/tcp

  ufw --force enable
}
