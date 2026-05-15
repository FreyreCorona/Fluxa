#!/usr/bin/env bash

create_base_fs() {
  mkdir -p /opt/platform/{services,data,logs}
  chown -R ubuntu:ubuntu /opt/platform
}

create_edge_dirs() {
  mkdir -p /opt/platform/{traefik,postgres}
  chown -R ubuntu:ubuntu /opt/platform
}

create_infra_dirs() {
  mkdir -p /opt/platform/{registry,gitea,monitoring,backups}
  chown -R ubuntu:ubuntu /opt/platform
}
