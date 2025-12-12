# Environment Promotion Strategy

## **Current Implementation: Single Environment**
- **Production**: `tbyte` namespace with full resources

## **Proposed Multi-Environment Strategy**

### **Environment Separation**
```
├── dev/          # Development (1 replica, minimal resources)
├── staging/      # Staging (2 replicas, production-like)  
└── production/   # Production (3+ replicas, full resources)
```

### **Promotion Pipeline**
```
PR → Dev → Merge → Staging → Manual Approval → Production
```

### **Implementation Approach**

#### **Option 1: Namespace-based (Recommended)**
```bash
# Different namespaces, same cluster
kubectl create namespace dev
kubectl create namespace staging  
kubectl create namespace production
```

#### **Option 2: Cluster-based (Enterprise)**
```bash
# Separate EKS clusters per environment
dev-cluster.eks.amazonaws.com
staging-cluster.eks.amazonaws.com  
prod-cluster.eks.amazonaws.com
```

### **Environment-Specific Configurations**

#### **Development Environment**
```yaml
# values-dev.yaml
replicaCount: 1
resources:
  requests:
    cpu: 50m
    memory: 64Mi
ingress:
  host: dev.tbyte.local
database:
  instance: db.t3.micro
```

#### **Staging Environment**  
```yaml
# values-staging.yaml
replicaCount: 2
resources:
  requests:
    cpu: 100m
    memory: 128Mi
ingress:
  host: staging.tbyte.local
database:
  instance: db.t3.small
```

#### **Production Environment**
```yaml
# values-prod.yaml  
replicaCount: 3
resources:
  requests:
    cpu: 200m
    memory: 256Mi
ingress:
  host: tbyte.local
database:
  instance: db.t3.medium
```

### **Deployment Commands**
```bash
# Deploy to dev
helm upgrade --install tbyte-dev ./apps/tbyte-microservices \
  -f values-dev.yaml -n dev

# Deploy to staging  
helm upgrade --install tbyte-staging ./apps/tbyte-microservices \
  -f values-staging.yaml -n staging

# Deploy to production
helm upgrade --install tbyte-prod ./apps/tbyte-microservices \
  -f values-prod.yaml -n production
```

### **Current Status**
- ✅ **Production Environment**: Fully implemented and working
- ❌ **Dev/Staging**: Not implemented (single environment approach used)
- ✅ **Pipeline**: GitHub Actions ready for multi-environment

### **Trade-off Decision**
**Chose single environment** for assessment to:
- Focus on core functionality over environment complexity
- Demonstrate working application faster
- Reduce infrastructure costs (~$175/month vs $500+/month)

**For production use**: Multi-environment strategy would be implemented with separate namespaces and environment-specific values files.
