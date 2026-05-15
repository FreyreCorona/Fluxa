# Platform Architecture

Estado actual:
- single control plane
- single worker
- internal infra node
- k3s-based runtime
- tailscale mesh networking

Objetivo:
Construir un PaaS pequeño, modular y portable,
manteniendo separación clara entre:
- edge
- control plane
- runtime
- internal infrastructure

---

# Filosofía de Diseño

La plataforma NO está acoplada a Kubernetes.

Kubernetes/k3s es solamente el runtime substrate actual.

La plataforma debe mantener:
- control plane propio
- API propia
- scheduler lógico propio
- metadata propia
- abstractions propias

Esto permite:
- migrar a Kubernetes completo después
- soportar Docker standalone
- soportar otros runtimes
- evitar convertirse en un wrapper de kubectl

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
                     |     |      |
                     |     |      |
                     |     |      +-------------------+
                     |                             |
                     v                             v
               Control Plane                PostgreSQL
                     |
                     |
                     v
              k3s API / Runtime
                     |
          +----------+----------+
          |                     |
          v                     v
   Worker Node(s)        Future Worker Nodes
      VPS #2

                     ^
                     |
                     |
              Tailscale Mesh
                     |
                     v

            +-------------------+
            | Internal Infra    |
            | Atom Ubuntu Node  |
            +-------------------+
```

---

# Layer 1 — Edge + Control Plane

Nodo:
- Oracle VPS #1

Responsabilidades:
- entrypoint HTTP/HTTPS
- TLS termination
- routing
- API pública
- auth
- domains
- orchestration metadata
- deployments
- scheduler lógico
- state management

Servicios:
- k3s server
- Traefik
- PostgreSQL
- Go Control API
- scheduler service
- ACME / Let's Encrypt
- rate limiting

---

## Decisiones de Diseño

### Traefik sobre Caddy

Traefik fue elegido porque:
- integra naturalmente con k3s
- soporta dynamic service discovery
- facilita ingress management
- escala mejor hacia Kubernetes completo

Aunque Caddy posee mejor ergonomía HTTP,
Traefik se alinea mejor con:
- orchestrators
- ingress patterns
- cloud-native routing

---

### PostgreSQL Local Temporalmente

PostgreSQL permanece en el Edge Node inicialmente.

Razones:
- menor complejidad operacional
- menos moving parts
- menor latencia interna
- infraestructura pequeña actualmente
- no existe necesidad real de HA

Migración futura:
- PostgreSQL separado
- backups remotos
- replication
- managed database opcional

---

### Control Plane Propio

Aunque se utiliza k3s:
- Kubernetes NO es el producto
- Kubernetes es solamente el runtime

La plataforma mantiene:
- auth propia
- deployments propios
- projects
- environments
- metadata
- API estable

Esto evita:
- acoplamiento excesivo
- dependencia total de Kubernetes APIs
- problemas futuros de migración

---

# Layer 2 — Runtime Layer

Nodo:
- Oracle VPS #2

Responsabilidades:
- ejecutar workloads clientes
- aislamiento runtime
- lifecycle management
- healthchecks
- logs
- metrics básicas

Servicios:
- k3s agent
- container runtime
- runtime agent (Go)
- log forwarding
- metrics exporter

---

## Decisiones de Diseño

### k3s por simplicidad operacional

k3s fue elegido porque:
- reduce complejidad
- elimina necesidad de construir scheduler
- simplifica networking
- simplifica orchestration
- simplifica service discovery

Esto permite:
- enfocarse en el producto
- enfocarse en UX
- enfocarse en deploy pipeline

En lugar de:
- reconstruir Kubernetes parcialmente

---

### Runtime Agent Propio

Aunque k3s ya maneja workloads,
se mantiene un runtime agent propio.

Responsabilidades:
- reporting
- observabilidad
- integración con control plane
- metadata local
- logs
- node health

Esto desacopla la plataforma del runtime real.

---

# Layer 3 — Internal Infrastructure

Nodo:
- Atom Ubuntu Server

Responsabilidades:
- CI/CD
- builds
- registry
- monitoring
- backups
- testing
- laboratorio interno

Servicios:
- Gitea
- CI runners
- Docker registry
- VictoriaMetrics
- Uptime Kuma
- build cache
- artifact storage

---

## Decisiones de Diseño

### Infraestructura interna separada

La infraestructura interna NO comparte runtime con workloads clientes.

Razones:
- aislamiento
- estabilidad
- builds no afectan producción
- backups aislados
- menor superficie de ataque

---

### Nodo no expuesto públicamente

El nodo infra:
- vive únicamente dentro de Tailscale
- no expone servicios directamente
- reduce riesgo operacional

---

# Layer 4 — Runtime Abstraction

El diseño completo depende de esta capa.

La plataforma NO habla directamente con:
- Docker
- Kubernetes
- containerd

La plataforma habla con una interfaz abstracta.

Ejemplo conceptual:

```go
type Runtime interface {
    Deploy(ctx context.Context, app App) error
    Stop(ctx context.Context, appID string) error
    Restart(ctx context.Context, appID string) error
    Logs(ctx context.Context, appID string) error
    Metrics(ctx context.Context, appID string) error
}
```

Implementaciones futuras:
- KubernetesRuntime
- DockerRuntime
- NomadRuntime
- FirecrackerRuntime

---

## Razones de esta abstracción

Permite:
- migraciones futuras
- testing local
- multi-runtime
- desacoplamiento
- evolución gradual

La API pública nunca depende del runtime específico.

---

# Networking

Toda la infraestructura pertenece a una misma red Tailscale.

Ventajas:
- overlay networking simplificado
- private networking automático
- WireGuard integrado
- node discovery
- menos configuración manual
- seguridad simplificada

---

# Deployment Flow

```text
git push
    ↓
CI/CD pipeline
    ↓
build image
    ↓
push registry
    ↓
control plane deployment request
    ↓
scheduler selecciona nodo
    ↓
k3s deploy
    ↓
Traefik actualiza routes
    ↓
SSL automático
    ↓
application online
```

---

# Scheduler Philosophy

El scheduler inicial será simple.

Factores:
- RAM disponible
- CPU disponible
- cantidad de workloads
- estado del nodo

NO se intentará:
- scheduling complejo
- autoscaling avanzado
- binpacking extremo

La complejidad operacional debe mantenerse baja inicialmente.

---

# Estado Actual

Actual:
- single edge node
- single worker node
- single infra node
- single PostgreSQL
- k3s lightweight cluster

Objetivo actual:
- estabilidad
- reproducibilidad
- velocidad de iteración

---

# Evolución Futura

## Fase 1
- estabilizar plataforma
- deploy pipeline
- observabilidad básica
- auth
- domains

## Fase 2
- múltiples workers
- Redis
- logs centralizados
- object storage
- backups automáticos

## Fase 3
- PostgreSQL separado
- HA parcial
- autoscaling
- multi-region

---

# Principios Arquitectónicos

- control plane separado del runtime
- infraestructura interna aislada
- simplicidad operacional primero
- abstractions antes que acoplamiento
- runtime portable
- stateless-first
- observabilidad desde el inicio
- automatización reproducible