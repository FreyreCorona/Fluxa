# Bootstrap

Sistema de bootstrapping para nodos de la plataforma Fluxa.

## Tipos de nodo

| Script | Perfil | Firewall | Directorios extra |
|--------|--------|----------|-------------------|
| `worker.sh` | Worker interno | Solo SSH | — |
| `infra.sh` | Infraestructura interna | Solo SSH | `registry`, `gitea`, `monitoring`, `backups` |
| `edge.sh` | Borde (público) | SSH + HTTP/HTTPS | `traefik`, `postgres` |

## Dependencias

Los tres scripts cargan las mismas librerías en `lib/`:

- **`common.sh`** — Funciones utilitarias (`log`, `require_root`)
- **`packages.sh`** — Instala paquetes base: `curl`, `wget`, `git`, `jq`, `htop`, `unzip`, `ca-certificates`, `gnupg`, `lsb-release`, `ufw`
- **`filesystem.sh`** — Crea `/opt/platform/{services,data,logs}` y directorios según el perfil
- **`firewall.sh`** — Configura `ufw`:
  - *Edge*: permite `22/tcp`, `80/tcp`, `443/tcp`
  - *Interno*: permite solo `22/tcp`
- **`docker.sh`** — Instala Docker Engine (`docker-ce`, `docker-ce-cli`, `containerd.io`, `buildx`, `compose`), agrega el usuario `ubuntu` al grupo `docker` y configura `daemon.json` con `live-restore` y rotación de logs (10 MB, 3 archivos)

## Uso

```bash
sudo ./bootstrap/edge.sh      # nodo de borde
sudo ./bootstrap/infra.sh     # nodo de infraestructura
sudo ./bootstrap/worker.sh    # nodo worker
```

Cada script debe ejecutarse como root en un sistema Ubuntu/Debian base.

## Orden de ejecución

1. Instalación de paquetes base
2. Creación de estructura de directorios
3. Configuración del firewall
4. Instalación y configuración de Docker

## Notas

- El usuario `ubuntu` debe hacer re-login después del bootstrap para que el grupo `docker` surta efecto.
- Los scripts usan `set -euo pipefail` para detenerse ante cualquier error.
- Todos los scripts fuente asumen que se ejecutan desde el directorio `bootstrap/`.
