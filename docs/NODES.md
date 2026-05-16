# Node Roles

Todos los nodos:
- pertenecen a la misma red Tailscale
- utilizan bootstrap reproducible
- poseen firewall configurado
- usan observabilidad básica
- utilizan acceso SSH mediante claves
- utilizan despliegues reproducibles
- priorizan aislamiento entre planos de responsabilidad

---

# EDGE NODE

Rol:
- edge
- ingress

Host:
- Oracle VPS #1

Responsabilidad:
- recibir tráfico público
- terminación TLS
- reverse proxy
- routing hacia workloads internos
- protección básica de acceso

Servicios:
- Traefik
- fail2ban
- metrics exporter

Networking:
- Tailscale
- firewall restrictivo

Exposición pública:
- sí

Puertos públicos:
- 80
- 443

Puertos privados:
- ninguno

Notas:
- nodo stateless
- no ejecuta workloads clientes
- no contiene bases de datos
- no contiene control plane Kubernetes
- únicamente enruta tráfico hacia servicios internos

---

# CONTROL / INFRA NODE

Rol:
- control plane
- infra

Host:
- Atom Ubuntu Server

Responsabilidad:
- administración del cluster
- API central del PaaS
- orchestration de deployments
- integración con GitHub
- observabilidad
- servicios internos de plataforma

Servicios:
- k3s server
- PostgreSQL
- Go API
- VictoriaMetrics
- Grafana
- UptimeKuma

Networking:
- únicamente Tailscale
- firewall restrictivo

Exposición pública:
- no

Puertos públicos:
- ninguno

Puertos privados:
- PostgreSQL
- k3s internal
- observabilidad

Notas:
- contiene estado crítico de la plataforma
- no expuesto directamente a internet
- Kubernetes realiza scheduling y orchestration
- la Go API abstrae deployments y gestión del PaaS
- preparado para futura separación entre control e infra

---

# WORKER NODE

Rol:
- runtime

Host:
- Oracle VPS #2

Responsabilidad:
- ejecutar workloads clientes
- ejecutar workloads internos
- aislamiento de workloads
- exposición indirecta mediante edge

Servicios:
- k3s agent
- runtime agent
- metrics exporter

Networking:
- únicamente Tailscale
- firewall restrictivo

Exposición pública:
- no

Notas:
- no contiene servicios críticos de plataforma
- no contiene bases de datos principales
- escalable horizontalmente
- diseñado para agregar más workers en el futuro
- los deployments son realizados mediante imágenes OCI generadas externamente

---

# Deployment Flow

Flujo esperado:
- cliente conecta repositorio GitHub
- GitHub Actions construye imagen OCI
- imagen publicada en GitHub Container Registry
- GitHub Actions consume API del PaaS
- Go API actualiza recursos Kubernetes
- Kubernetes realiza deployment en workers

Requerimientos mínimos:
- Dockerfile válido
- acceso al registry OCI
- secrets de deployment configurados

Responsabilidades del PaaS:
- deployments
- ingress
- TLS
- dominios
- observabilidad básica
- aislamiento entre tenants
- lifecycle de aplicaciones

Responsabilidades del cliente:
- código fuente
- pipeline CI/CD
- construcción de imágenes
- mantenimiento de aplicación