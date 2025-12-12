# TByte DevOps Assessment - Live Demo Script

## 🎯 Quick Demo (5 minutes)

### 1. Setup Access
```bash
# Add to /etc/hosts
echo "52.29.44.16 tbyte.local" | sudo tee -a /etc/hosts
```

### 2. Frontend Demo
```bash
# Open web application
open http://tbyte.local

# Or test with curl
curl -H "Host: tbyte.local" http://52.29.44.16/ | head -10
```
**Expected**: Clean HTML dashboard with "TByte Microservices Platform"

### 3. Backend API Demo
```bash
# Health check endpoint
curl -H "Host: tbyte.local" http://52.29.44.16/api/health | jq .

# Users from PostgreSQL RDS
curl -H "Host: tbyte.local" http://52.29.44.16/api/users | jq .
```
**Expected**: 
- Health: `{"status":"healthy","service":"tbyte-backend","version":"1.0.0"}`
- Users: 3 users from database with names, emails, timestamps

### 4. Infrastructure Verification
```bash
# Check EKS cluster
kubectl get nodes

# Check application pods (should show 2/2 with Istio sidecars)
kubectl get pods -n tbyte

# Check Istio service mesh
kubectl get gateway,virtualservice -n istio-system

# Check monitoring stack
kubectl get pods -n monitoring
```

## 🔧 Full Technical Demo (15 minutes)

### Infrastructure Components
```bash
# EKS cluster info
kubectl cluster-info

# Terraform state
cd terraform && terraform show | head -20

# ArgoCD applications
kubectl get applications -n argocd
```

### Service Mesh Deep Dive
```bash
# Istio configuration
kubectl get gateway common-gateway -n istio-system -o yaml

# VirtualService routing rules
kubectl get virtualservice common-routes -n istio-system -o yaml

# Pod sidecars (should be 2/2)
kubectl get pods -n tbyte -o wide
```

### Database Integration
```bash
# External Secrets Operator
kubectl get externalsecret -n tbyte

# RDS connection test
kubectl logs -n tbyte -l app.kubernetes.io/component=backend --tail=5
```

### Monitoring & Observability
```bash
# Port forward to Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 &

# Get Grafana password
kubectl get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d

# Open Grafana
open http://localhost:3000
```

### Autoscaling Demo
```bash
# Check KEDA ScaledObjects
kubectl get scaledobject -n tbyte

# Check Karpenter node provisioning
kubectl get nodes -l karpenter.sh/provisioner-name

# Generate load (optional)
kubectl run load-test --image=busybox --rm -it --restart=Never -- /bin/sh
# while true; do wget -q -O- http://tbyte-microservices-frontend.tbyte/; done
```

## 🎯 Key Demo Points

### 1. **Working Application**
- Frontend serves clean web dashboard
- Backend API returns JSON responses
- Database integration with real data

### 2. **Service Mesh Magic**
- Istio automatically rewrites `/api/health` → `/health`
- Load balancing across multiple backend pods
- All pods have sidecars (2/2 containers)

### 3. **Production Features**
- KEDA autoscaling based on CPU/memory
- External Secrets Operator managing RDS credentials
- NetworkPolicies for security
- Health probes for reliability

### 4. **GitOps Automation**
- ArgoCD managing all deployments
- GitHub Actions CI/CD pipeline
- Infrastructure as Code with Terraform

### 5. **Observability**
- Prometheus collecting metrics
- Grafana dashboards available
- Loki aggregating logs
- All integrated and working

## 🚨 Troubleshooting

### If Frontend Not Loading
```bash
# Check frontend pods
kubectl get pods -n tbyte -l app.kubernetes.io/component=frontend

# Check service
kubectl get svc -n tbyte -l app.kubernetes.io/component=frontend

# Port forward directly
kubectl port-forward -n tbyte svc/tbyte-microservices-frontend 8080:80
open http://localhost:8080
```

### If Backend API Failing
```bash
# Check backend pods
kubectl get pods -n tbyte -l app.kubernetes.io/component=backend

# Check logs
kubectl logs -n tbyte -l app.kubernetes.io/component=backend --tail=10

# Test direct connection
kubectl port-forward -n tbyte svc/tbyte-microservices-backend 3000:3000
curl http://localhost:3000/health
```

### If Database Connection Issues
```bash
# Check External Secrets
kubectl get externalsecret -n tbyte -o yaml

# Check secret creation
kubectl get secret rds-credentials -n tbyte -o yaml

# Check backend logs for DB errors
kubectl logs -n tbyte -l app.kubernetes.io/component=backend | grep -i error
```

## 📊 Success Metrics

✅ **Frontend**: HTTP 200, clean HTML dashboard  
✅ **Backend Health**: `{"status":"healthy"}`  
✅ **Backend Users**: 3 users returned from RDS  
✅ **Service Mesh**: 2/2 containers (app + istio-proxy)  
✅ **Autoscaling**: ScaledObjects active  
✅ **Monitoring**: Grafana accessible with dashboards  
✅ **GitOps**: ArgoCD applications synced  

**Result**: Complete end-to-end working solution! 🎉
