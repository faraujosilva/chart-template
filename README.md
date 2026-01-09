# Platform MVP - Infrastructure-Aware Application Chart

Deploy your application with optional cloud infrastructure provisioning via HCP Terraform.

**O desenvolvedor escolhe o FLAVOR (capacidade/performance). A plataforma decide a cloud (AWS/Azure).**

## Quick Start

### Simple Application (sem infra)

```bash
helm install my-app ./charts/app \
  --set app.name=my-api \
  --set app.team=backend-team \
  --set image.repository=nginx
```

### Application com Storage

```bash
helm install my-app ./charts/app \
  --set app.name=media-service \
  --set app.team=media-team \
  --set infrastructure.enabled=true \
  --set infrastructure.storage.enabled=true \
  --set infrastructure.storage.flavor=standard
```

### Full Stack (Storage + Database + Cache)

```bash
helm install my-app ./charts/app -f examples/full-stack-app.yaml -n prod
```

## Infrastructure Flavors

### Storage Flavors

| Flavor | Uso Recomendado |
|--------|-----------------|
| `standard` | Uso geral, assets, uploads (acesso frequente) |
| `premium` | Analytics, data lakes (alta performance) |
| `economy` | Backups, logs antigos (acesso infrequente) |
| `archive` | Compliance, histórico (armazenamento frio) |

### Database Flavors

| Flavor | Recursos |
|--------|----------|
| `small` | 2 vCPU, 4GB RAM (dev/testes) |
| `medium` | 4 vCPU, 8GB RAM (produção leve) |
| `large` | 8 vCPU, 32GB RAM (produção) |
| `xlarge` | 16 vCPU, 64GB RAM (alta demanda) |

**Engines:** `postgres`, `mysql`

### Cache Flavors

| Flavor | Memória |
|--------|---------|
| `small` | 1.5GB (dev/cache básico) |
| `medium` | 6GB (produção) |
| `large` | 13GB (alta demanda) |

**Engines:** `redis`, `memcached`

## Como Funciona

```
Developer (values.yaml)
        │
        │  infrastructure:
        │    storage:
        │      flavor: standard   ◄── Escolhe capacidade
        │    database:
        │      engine: postgres
        │      flavor: medium     ◄── Escolhe tamanho
        │
        ▼
┌─────────────────┐
│   Helm Chart    │  Gera Workspace CRs
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  HCP Terraform  │  Traduz flavor → recurso cloud
│    Operator     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Cloud Resource │  S3, RDS, ElastiCache
│  (AWS / Azure)  │  ou Azure equivalente
└─────────────────┘
```

A plataforma traduz os flavors:
- `storage.flavor: standard` → AWS S3 Standard **ou** Azure Blob Hot
- `database.flavor: medium` → RDS db.r6g.large **ou** Azure D4s
- `cache.flavor: small` → ElastiCache cache.t3.small **ou** Azure C0

## Exemplo Completo

```yaml
app:
  name: my-api
  team: backend-team

image:
  repository: my-registry/my-api
  tag: "v1.0.0"

replicaCount: 3

infrastructure:
  enabled: true

  storage:
    enabled: true
    flavor: standard
    size: 100Gi

  database:
    enabled: true
    engine: postgres
    flavor: medium
    highAvailability: true

  cache:
    enabled: true
    engine: redis
    flavor: small
```
