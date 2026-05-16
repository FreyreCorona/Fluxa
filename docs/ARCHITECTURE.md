# Platform Architecture

Estado actual:
- single edge node
- single control/infra node
- single worker
- k3s-based runtime
- tailscale mesh networking
- GitHub-based CI/CD flow

Objetivo:
Construir un PaaS pequeño, modular y portable,
manteniendo separación clara entre:
- edge
- control plane
- runtime
- internal infrastructure

---

# Filosofía de Diseño

La plataforma NO expone Kubernetes directamente al cliente.

Kubernetes/k3s es el runtime substrate actual.

La plataforma abstrae:
- deployments
- domains
- ingress
- lifecycle
- observabilidad básica

El objetivo es ofrecer:
- deploy simplificado
- integración con GitHub
- aislamiento entre tenants
- runtime reproducible

---

# Arquitectura General

```text
                        Internet
                            |
                            v
                    +----------------+
                    |   Edge Node    |
                    | VPS Oracle #1  |
                    +----------------+
                            |
                            |
                            v

                 +----------------------+
                 | Control / Infra Node |
                 |  Atom Ubuntu Server  |
                 +----------------------+
                    |       |        |
                    |       |        |
                    |       |        +------------------+
                    |       |                           |
                    |       v                           v
                    |   PostgreSQL               Observability
                    |
                    v

                 k3s Control Plane
                    |
         +----------+----------+
         |                     |
         v                     v

    Worker Node(s)      Future Worker Nodes
      Oracle VPS #2

                    ^
                    |
                    |
             Tailscale Mesh
```

---

# Layer 1 — Edge Layer

Nodo:
- Oracle VPS #1

Responsabilidades:
- entrypoint HTTP/HTTPS
- TLS termination
- reverse proxy
- routing
- protección básica
- forwarding hacia workloads internos

Servicios:
- Traefik
- fail2ban
- metrics exporter

---

## Decisiones de Diseño

### Edge Stateless

El Edge Node:
- no almacena estado crítico
- no contiene bases de datos
- no ejecuta workloads clientes
- no contiene control plane Kubernetes

Esto permite:
- reemplazo rápido
- menor blast radius
- menor complejidad operacional

---

### Traefik como ingress layer

Traefik fue elegido porque:
- integra naturalmente con k3s
- soporta dynamic service discovery
- facilita ingress management
- simplifica TLS automático
- se alinea con patrones cloud-native

---

# Layer 2 — Control Plane + Internal Infrastructure

Nodo:
- Atom Ubuntu Server

Responsabilidades:
- administración del cluster
- API central del PaaS
- orchestration de deployments
- metadata de plataforma
- integración con GitHub
- observabilidad
- servicios internos

Servicios:
- k3s server
- PostgreSQL
- Go Control API
- VictoriaMetrics
- Grafana
- UptimeKuma

---

## Decisiones de Diseño

### Kubernetes como runtime substrate

k3s fue elegido porque:
- reduce complejidad operacional
- simplifica orchestration
- simplifica networking
- simplifica service discovery
- simplifica lifecycle management

La plataforma NO reemplaza Kubernetes.

Kubernetes:
- schedulea workloads
- maneja networking interno
- realiza reconciliation
- maneja restart policies
- maneja deployments

La plataforma abstrae:
- UX
- deployment workflow
- tenant management
- ingress
- domains
- metadata

---

### Go API como control layer

La Go API NO es un scheduler distribuido complejo.

Responsabilidades:
- deployments
- integración GitHub
- integración CI/CD
- metadata
- tenant management
- domains
- lifecycle de aplicaciones

La API traduce requests de plataforma hacia:
- Deployments
- Services
- Ingresses
- Secrets
- Namespaces

de Kubernetes.

---

### PostgreSQL centralizado inicialmente

PostgreSQL permanece en el Control Node inicialmente.

Razones:
- menor complejidad operacional
- pocos recursos disponibles
- menor cantidad de moving parts
- no existe necesidad real de HA

Migración futura:
- PostgreSQL separado
- replication
- backups remotos
- HA parcial

---

### Observabilidad separada del runtime

La observabilidad vive fuera de los workers.

Ventajas:
- debugging más simple
- workloads clientes aislados
- métricas persistentes
- menor impacto operacional

---

# Layer 3 — Runtime Layer

Nodo:
- Oracle VPS #2

Responsabilidades:
- ejecutar workloads clientes
- ejecutar workloads internos
- runtime isolation
- healthchecks
- logs
- métricas básicas

Servicios:
- k3s agent
- runtime agent
- metrics exporter

---

## Decisiones de Diseño

### Workers especializados

Los workers:
- no contienen servicios críticos
- no contienen bases de datos principales
- no contienen control plane
- no exponen servicios públicamente

Esto permite:
- scaling horizontal
- aislamiento
- menor riesgo operacional

---

### Runtime Agent ligero

El runtime agent existe para:
- reporting
- métricas
- observabilidad
- health status
- metadata local

NO reemplaza Kubernetes.

---

# Networking

Toda la infraestructura pertenece a una misma red Tailscale.

Ventajas:
- private networking automático
- WireGuard integrado
- overlay networking simplificado
- node discovery
- menor exposición pública
- configuración simplificada

---

# Deployment Flow

```text
git push
    ↓
GitHub Actions
    ↓
build image
    ↓
push GHCR
    ↓
deployment request
    ↓
Go API
    ↓
Kubernetes Deployment update
    ↓
k3s scheduling
    ↓
Traefik ingress update
    ↓
TLS automático
    ↓
application online
```

---

# Deployment Model

El contrato principal de la plataforma es:

```text
Dockerfile válido = deployment soportado
```

El cliente:
- mantiene código fuente
- mantiene pipeline CI/CD
- construye imágenes OCI
- publica imágenes

La plataforma:
- ejecuta workloads
- administra ingress
- administra TLS
- administra domains
- administra runtime
- administra observabilidad básica

---

# GitHub-Centric Workflow

La plataforma externaliza:
- Git hosting
- CI/CD
- container registry
- documentación estática

Servicios utilizados:
- GitHub
- GitHub Actions
- GitHub Container Registry
- GitHub Pages

Razones:
- menor consumo de recursos
- menor complejidad operacional
- menor mantenimiento
- enfoque en el core del PaaS

---

# Scheduler Philosophy

Inicialmente NO existe scheduler complejo propio.

Kubernetes realiza:
- placement
- balancing
- lifecycle
- reconciliation

La plataforma solamente puede aplicar:
- node selection
- affinity
- quotas
- limits
- metadata lógica

La complejidad operacional debe mantenerse baja.

---

# Estado Actual

Actual:
- single edge node
- single control/infra node
- single worker node
- single PostgreSQL
- lightweight k3s cluster

Objetivo actual:
- estabilidad
- reproducibilidad
- velocidad de iteración
- bajo costo operacional

---

# Evolución Futura

## Fase 1
- estabilizar plataforma
- auth
- deployment API
- domains
- observabilidad básica

## Fase 2
- múltiples workers
- logs centralizados
- object storage
- backups automáticos
- tenant isolation mejorado

## Fase 3
- PostgreSQL separado
- HA parcial
- autoscaling
- multi-region
- edge redundancy

---

# Principios Arquitectónicos

- Kubernetes como runtime, no como producto
- control plane separado del runtime
- edge stateless
- infraestructura interna aislada
- simplicidad operacional primero
- abstractions antes que complejidad
- stateless-first
- observabilidad desde el inicio
- automatización reproducible
- evolución gradual
- foco en deployment UX