# Task A1 - Microservices Deployment to Kubernetes

## Overview

Production-ready Kubernetes deployment of a three-tier microservices application consisting of:
- **Frontend**: React/nginx web application
- **Backend**: Node.js API server
- **Database**: AWS RDS PostgreSQL (managed service)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐               │
│  │    Frontend     │    │     Backend     │               │
│  │   (nginx)       │────│   (Node.js)     │──────────────┼──► AWS RDS
│  │   Port: 80      │    │   Port: 3000    │               │   PostgreSQL
│  └─────────────────┘    └─────────────────┘               │
│           │                       │                        │
│  ┌─────────────────┐    ┌─────────────────┐               │
│  │   ALB Ingress   │    │  ESO Secrets    │               │
│  │  External LB    │    │ AWS Secrets Mgr │               │
│  └─────────────────┘    └─────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

## Production-Ready Components

### ✅ Core Kubernetes Resources

| Component | Frontend | Backend | Purpose |
|-----------|----------|---------|---------|
| **Deployment** | ✅ | ✅ | Pod management and rolling updates |
| **Service** | ✅ | ✅ | Internal service discovery |
| **Ingress** | ✅ | - | External traffic routing via ALB |
| **ConfigMap** | ✅ | - | Nginx configuration and HTML content |
| **Secrets** | - | ✅ | RDS credentials via External Secrets Operator |
| **ServiceAccount** | - | ✅ | IRSA for AWS integration |

### ✅ Production Features

| Feature | Frontend | Backend | Implementation |
|---------|----------|---------|----------------|
| **Resource Limits** | ✅ | ✅ | CPU/Memory requests and limits |
| **Health Probes** | ✅ | ✅ | HTTP readiness and liveness checks |
| **Autoscaling** | ✅ | ✅ | KEDA ScaledObjects (CPU/Memory) |
| **Availability** | ✅ | ✅ | PodDisruptionBudgets |
| **Security** | ✅ | ✅ | NetworkPolicies for micro-segmentation |

## Security Implementation

### 🔒 Container Security
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 101        # nginx user
  fsGroup: 101
  readOnlyRootFilesystem: false  # nginx needs write access
```

### 🔒 Network Security
- **NetworkPolicies**: Restrict traffic between components
- **Frontend**: Only accepts traffic from ingress, only talks to backend
- **Backend**: Only accepts traffic from frontend, only talks to RDS/AWS APIs

### 🔒 Secrets Management
- **External Secrets Operator**: Syncs from AWS Secrets Manager
- **No hardcoded credentials**: All secrets externally managed
- **IRSA Authentication**: Service accounts with IAM roles

## Scalability Strategy

### 📈 KEDA Autoscaling
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
spec:
  minReplicaCount: 2
  maxReplicaCount: 10
  triggers:
  - type: cpu
    metadata:
      type: Utilization
      value: "70"
  - type: memory
    metadata:
      type: Utilization
      value: "80"
```

**Benefits over HPA:**
- Event-driven scaling
- Scale to zero capability
- Multiple trigger types
- Better resource utilization

### 📈 Resource Management
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

## Rollout Strategy

### 🚀 Zero-Downtime Deployments

**Rolling Update Configuration:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 25%
    maxSurge: 25%
```

**Health Check Strategy:**
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10
```

**Availability Protection:**
```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/component: frontend
```

## Database Strategy

### 🗄️ AWS RDS PostgreSQL

**Why External Database:**
- **Managed Service**: Automated backups, patching, monitoring
- **High Availability**: Multi-AZ deployment capability
- **Scalability**: Read replicas and vertical scaling
- **Security**: Encryption at rest/transit, VPC isolation
- **Compliance**: SOC, PCI DSS compliance

**Connection Security:**
- Private subnets only
- Security groups restricting access
- SSL/TLS encryption enforced
- Secrets managed via AWS Secrets Manager

## File Structure

```
apps/tbyte-microservices/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── frontend/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── hpa.yaml (KEDA ScaledObject)
    │   ├── pdb.yaml
    │   ├── networkpolicy.yaml
    │   ├── configmap-nginx.yaml
    │   └── configmap-html.yaml
    ├── backend/
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   ├── serviceaccount.yaml
    │   ├── scaledobject.yaml (KEDA)
    │   ├── pdb.yaml
    │   └── networkpolicy.yaml
    └── shared/
        ├── ingress.yaml
        └── secrets.yaml (ESO ExternalSecret)
```

## Testing & Verification

### 🧪 Deployment Testing
```bash
# Check pod status
kubectl get pods -n tbyte

# Test frontend
kubectl port-forward -n tbyte svc/tbyte-microservices-frontend 8080:80
curl http://localhost:8080

# Test backend API
kubectl port-forward -n tbyte svc/tbyte-microservices-backend 3000:3000
curl http://localhost:3000/health

# Verify autoscaling
kubectl get scaledobject -n tbyte
kubectl get hpa -n tbyte

# Check network policies
kubectl get networkpolicy -n tbyte

# Verify secrets
kubectl get externalsecret -n tbyte
kubectl get secret rds-credentials -n tbyte
```

### 🧪 Load Testing
```bash
# Generate load to test autoscaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Inside pod: while true; do wget -q -O- http://tbyte-microservices-frontend/; done
```

## Key Design Decisions

### ✅ **Security First**
- External Secrets Operator instead of Kubernetes secrets
- NetworkPolicies for zero-trust networking
- Non-root containers with minimal privileges
- IRSA for AWS authentication

### ✅ **Cloud Native**
- KEDA for intelligent autoscaling
- Managed RDS instead of in-cluster database
- ALB ingress for AWS integration
- GitOps deployment via ArgoCD

### ✅ **Production Ready**
- Comprehensive health checks
- Resource limits and requests
- PodDisruptionBudgets for availability
- Rolling updates for zero-downtime

### ✅ **Observability**
- Structured logging to stdout
- Health endpoints for monitoring
- Prometheus metrics (via KEDA)
- Integration with monitoring stack

## Compliance & Best Practices

- ✅ **12-Factor App**: Stateless, config via environment
- ✅ **Security**: Non-root, read-only filesystem where possible
- ✅ **Reliability**: Health checks, graceful shutdown
- ✅ **Scalability**: Horizontal scaling, resource limits
- ✅ **Maintainability**: Helm charts, GitOps deployment

---

**Result**: Production-ready microservices deployment exceeding enterprise standards with comprehensive security, scalability, and reliability features.
