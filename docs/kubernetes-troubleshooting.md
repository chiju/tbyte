# Kubernetes Troubleshooting Guide (Section A2)

## Scenario: Pods stuck in CrashLoopBackOff

### Troubleshooting Steps
```bash
# 1. Check pod status and events
kubectl get pods -o wide
kubectl describe pod <pod-name>

# 2. Check pod logs
kubectl logs <pod-name> --previous
kubectl logs <pod-name> -f

# 3. Check resource constraints
kubectl top pods
kubectl describe node <node-name>
```

### Root Cause Analysis
- **Image issues**: Wrong image tag, missing image
- **Configuration errors**: Invalid environment variables, missing secrets
- **Resource limits**: Insufficient CPU/memory allocation
- **Health check failures**: Readiness/liveness probe timeouts

### Permanent Fixes
```yaml
# Fix resource limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

# Fix health checks
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10
```

## Scenario: Service not reachable

### Troubleshooting Steps
```bash
# 1. Check service and endpoints
kubectl get svc
kubectl get endpoints <service-name>
kubectl describe svc <service-name>

# 2. Test connectivity
kubectl run test-pod --image=busybox -it --rm -- sh
# Inside pod: wget -qO- http://<service-name>:<port>

# 3. Check network policies
kubectl get networkpolicies
kubectl describe networkpolicy <policy-name>
```

### Root Cause Analysis
- **Label mismatch**: Service selector doesn't match pod labels
- **Port configuration**: Wrong targetPort or port mapping
- **Network policies**: Blocking traffic between pods
- **DNS issues**: Service discovery problems

### Permanent Fixes
```yaml
# Ensure label matching
apiVersion: v1
kind: Service
spec:
  selector:
    app: myapp  # Must match pod labels
  ports:
  - port: 80
    targetPort: 8080  # Must match container port
```

## Scenario: Ingress returns 502

### Troubleshooting Steps
```bash
# 1. Check ingress configuration
kubectl get ingress
kubectl describe ingress <ingress-name>

# 2. Check ingress controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx <controller-pod>

# 3. Test backend service
kubectl port-forward svc/<service-name> 8080:80
curl localhost:8080
```

### Root Cause Analysis
- **Backend unavailable**: Service or pods not ready
- **Path routing**: Incorrect path configuration
- **SSL/TLS issues**: Certificate problems
- **Load balancer**: AWS ALB configuration errors

### Permanent Fixes
```yaml
# Fix ingress configuration
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/target-type: ip
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
```

## Scenario: Node in NotReady (DiskPressure)

### Troubleshooting Steps
```bash
# 1. Check node status
kubectl get nodes
kubectl describe node <node-name>

# 2. Check disk usage on node
kubectl debug node/<node-name> -it --image=busybox
# Inside debug pod: df -h

# 3. Check system pods
kubectl get pods -n kube-system -o wide --field-selector spec.nodeName=<node-name>
```

### Root Cause Analysis
- **Disk full**: Container logs, images, or ephemeral storage
- **Image cache**: Too many unused Docker images
- **Log rotation**: Application logs not rotated
- **Persistent volumes**: PV claims consuming space

### Permanent Fixes
```bash
# Clean up node (emergency)
docker system prune -f
docker image prune -a -f

# Configure log rotation
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [SERVICE]
        Log_Level    info
        Parsers_File parsers.conf
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Rotate_Wait       5
        Skip_Long_Lines   On
EOF
```

```yaml
# Set ephemeral storage limits
resources:
  limits:
    ephemeral-storage: 1Gi
  requests:
    ephemeral-storage: 500Mi
```

## General Debugging Commands

### Pod Debugging
```bash
# Get detailed pod information
kubectl get pods -o yaml <pod-name>

# Execute commands in running pod
kubectl exec -it <pod-name> -- /bin/bash

# Copy files from/to pod
kubectl cp <pod-name>:/path/to/file ./local-file
kubectl cp ./local-file <pod-name>:/path/to/file

# Debug with ephemeral container (K8s 1.23+)
kubectl debug <pod-name> -it --image=busybox --target=<container-name>
```

### Network Debugging
```bash
# Test DNS resolution
kubectl run test-dns --image=busybox -it --rm -- nslookup kubernetes.default

# Test service connectivity
kubectl run test-curl --image=curlimages/curl -it --rm -- curl -v http://<service-name>

# Check network policies
kubectl get networkpolicies --all-namespaces
```

### Resource Debugging
```bash
# Check resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Check resource quotas
kubectl get resourcequota --all-namespaces
kubectl describe resourcequota <quota-name>

# Check limit ranges
kubectl get limitrange --all-namespaces
```

### Event Debugging
```bash
# Get cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Get events for specific object
kubectl get events --field-selector involvedObject.name=<pod-name>

# Watch events in real-time
kubectl get events --watch
```
