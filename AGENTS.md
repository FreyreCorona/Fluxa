# Fluxa — Contexto del proyecto

## Objetivo principal

Aprender Terraform, Kubernetes y Go (patrón operator) en profundidad construyendo una plataforma de hosting real sobre Oracle Cloud + nodo físico local.

No se busca copiar código. El agente guía, el usuario investiga e implementa.

## Arquitectura

```
Terraform → provisiona VPS (Oracle Free Tier + PC casa)
    ↓
k3s instalado via cloud-init en cada nodo
    ↓
Kubernetes Operator (Go) corriendo en k3s
    ↓
CRD: FluxaService → gestiona servicios por cliente
    ├── Crea namespace aislado con ResourceQuota
    ├── Despliega Deployment + Service + Ingress
    └── Expone endpoint (HTTP estático, bot, API, etc.)
```

Cada cliente = un `kubectl apply -f service.yaml`.

El operador decide dónde y cómo desplegar según el `tier`.

## Repositorios

| Repo | Visibilidad | Contenido |
|---|---|---|
| `FreyreCorona/Fluxa` | Privado | Terraform, docs, configs de infra, operador V2+ |
| `FreyreCorona/FluxOperator` | Público | Operador V1 (CV, cualquiera puede contribuir) |
| `FreyreCorona/FluxCache` | Público | Cache distribuido en memoria (experimento aparte) |

FluxOperator V1 es pública para el CV. V2+ vive solo en Fluxa privado.

## Stack

- **Cloud**: Oracle Cloud (Always Free: 2 AMD + ARM A1 futuro)
- **IaC**: Terraform (provider OCI)
- **Orquestación**: k3s (Kubernetes lightweight)
- **Operador**: Go + controller-runtime
- **CI/CD**: GitHub Actions
- **Nodo físico**: PC en casa (futuro) integrable vía Tailscale + Terraform

## Plan de aprendizaje

### Fase 1 — Terraform (2-3 semanas)

Construir desde cero el `terraform/` aprendiendo cada recurso OCI:

1. Provider OCI, init/plan/apply, state local
2. VCN + subred + security list
3. VM (compute instance) con shape always-free
4. IP pública + reglas de ingreso (SSH, HTTP, HTTPS)
5. Variables, outputs, tfvars
6. Modules (vcn, compute, lb)
7. Remote state (Object Storage como backend)
8. Load Balancer + target group + health check

Cada paso es un commit. Sin copiar código — entender qué hace cada recurso.

### Fase 2 — k3s + multi-tenancy (2-3 semanas)

1. Instalar k3s manual en VPS
2. Cloud-init con k3s desde Terraform
3. Namespaces + ResourceQuota + LimitRange
4. NetworkPolicy (aislamiento entre clientes)
5. Deployment + Service + Ingress manual
6. Traefik (built-in de k3s)
7. Helm chart básico

### Fase 3 — Operator en Go (3-4 semanas)

1. Scaffold con controller-runtime
2. CRD `FluxaService` (tier, domain, image, replicas)
3. Reconciler: crear namespace + quota
4. Reconciler: deployment + service + ingress
5. Status updates
6. Finalizers (manejar borrado)
7. Tests de integración con envtest
8. Build + deploy a k3s

## Decisiones de arquitectura

- **Por qué k3s y no k8s vanilla**: Más simple, Traefik incluido, ideal para edge/free tier.
- **Por qué operator y no Helm a secas**: El operador abstrae la complejidad de k8s en un CRD simple. El cliente solo escribe 10 líneas de YAML. Además es el skill más diferencial para Platform Engineer.
- **Por qué Terraform separado del operador**: Terraform provisiona la infra (VPS, VCN, LB). El operador gestiona servicios dentro del cluster. Responsabilidades distintas.
- **Por qué separar repos público/privado**: El V1 público es para el CV y contribuciones. El privado tiene lógica de negocio (pricing, billing, clientes reales).

## Notas para el agente

- No escribir código por el usuario — guiar para que él investigue e implemente.
- Explicar el *qué* y el *por qué*, no el *cómo*.
- Señalar la documentación oficial relevante antes de sugerir implementación.
- Verificar que el usuario entiende cada paso antes de avanzar.
