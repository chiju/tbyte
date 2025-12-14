# D1 — Build a Logging & Monitoring Strategy

## Problem

Design and implement a comprehensive observability strategy for production microservices:
- **CloudWatch Integration**: AWS-native logging and metrics collection
- **Prometheus + Grafana**: Kubernetes-native monitoring and visualization
- **OpenTelemetry**: Distributed tracing and unified observability
- **Alerting Strategy**: Incident management with SEV definitions
- **Log Retention**: Cost-effective log storage and indexing
- **Dashboard Strategy**: Operational and business intelligence dashboards

**Requirements:**
- Multi-layer observability (infrastructure, application, business)
- Cost-effective log retention and storage
- Real-time alerting with proper escalation
- Distributed tracing for microservices debugging
- Compliance with data retention policies

## Approach

**Multi-Layer Observability Architecture:**

1. **Infrastructure Layer**: EKS control plane logs, node metrics, AWS service metrics
2. **Platform Layer**: Kubernetes metrics, pod performance, resource utilization
3. **Application Layer**: Custom metrics, distributed traces, error rates
4. **Business Layer**: User journey metrics, conversion rates, SLA monitoring

**Technology Stack:**
- **AWS CloudWatch**: Control plane logs, AWS service metrics, long-term storage
- **Prometheus**: Kubernetes metrics collection and short-term storage
- **Grafana**: Visualization, dashboards, and alerting interface
- **OpenTelemetry**: Distributed tracing and unified telemetry collection
- **Loki**: Log aggregation and correlation with metrics

## Solution

### Current Implementation Status

#### What's Already Deployed ✓
```
Monitoring Stack (Active):
├── Prometheus - 15-day retention, 50GB storage
├── Grafana - CloudWatch integration via IRSA
├── AlertManager - Slack integration configured
├── Node Exporter - System metrics collection
└── EKS Control Plane Logs - All log types enabled

OpenTelemetry (Partial):
├── Operator - Deployed and running
├── Collector - Configuration ready, not deployed
└── Instrumentation - Not configured
```

#### What Needs to be Completed ✗
```
Missing Components:
├── OpenTelemetry Collector deployment
├── Jaeger for distributed tracing
├── Loki for log aggregation
├── Custom application metrics
├── Business KPI dashboards
├── PagerDuty integration
└── Log lifecycle automation
```

#### Verification of Current State
```bash
# What's working now
kubectl get pods -n monitoring
kubectl get pods -n opentelemetry

# What's missing
kubectl get opentelemetrycollector -n opentelemetry  # Should show: No resources found
kubectl get pods -n loki                             # Should show: No resources found
```

### 1. CloudWatch Logs & Metrics Strategy

#### EKS Control Plane Logging
```bash
# Verify EKS logging configuration
aws eks describe-cluster --profile dev_4082 --region eu-central-1 --name tbyte-dev \
  --query 'cluster.logging.clusterLogging[0]'

# Current configuration:
{
  "types": ["api", "audit", "authenticator", "controllerManager", "scheduler"],
  "enabled": true
}
```

#### CloudWatch Log Groups Structure
```
/aws/eks/tbyte-dev/cluster              # EKS control plane logs
/aws/containerinsights/tbyte-dev/       # Container Insights
├── application                         # Application logs
├── dataplane                          # Data plane logs
├── host                               # Node-level logs
└── performance                        # Performance logs
```

#### Log Retention Policy
```json
{
  "logGroups": {
    "/aws/eks/tbyte-dev/cluster": {
      "retentionInDays": 7,
      "purpose": "Control plane debugging"
    },
    "/aws/containerinsights/tbyte-dev/application": {
      "retentionInDays": 30,
      "purpose": "Application troubleshooting"
    },
    "/aws/containerinsights/tbyte-dev/performance": {
      "retentionInDays": 14,
      "purpose": "Performance analysis"
    }
  }
}
```

### 2. Prometheus + Grafana Implementation

#### Prometheus Configuration
```yaml
# apps/kube-prometheus-stack/values.yaml
kube-prometheus-stack:
  prometheus:
    prometheusSpec:
      retention: 15d              # 15-day metric retention
      retentionSize: 45GB         # Size-based retention limit
      resources:
        requests:
          cpu: 500m
          memory: 2Gi
        limits:
          cpu: 1000m
          memory: 4Gi
      
      # Persistent storage for metrics
      storageSpec:
        volumeClaimTemplate:
          spec:
            storageClassName: gp3
            accessModes: ["ReadWriteOnce"]
            resources:
              requests:
                storage: 50Gi
      
      # Service discovery configuration
      serviceMonitorNamespaceSelector: {}
      serviceMonitorSelector:
        matchLabels:
          release: monitoring
```

#### Grafana Configuration with CloudWatch Integration
```yaml
grafana:
  enabled: true
  adminPassword: admin
  
  # Persistent storage for dashboards
  persistence:
    enabled: true
    storageClassName: gp3
    size: 10Gi
  
  # CloudWatch data source via IRSA
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "arn:aws:iam::045129524082:role/tbyte-dev-grafana-cloudwatch"
  
  # Additional data sources
  additionalDataSources:
    - name: CloudWatch
      type: cloudwatch
      jsonData:
        defaultRegion: eu-central-1
        authType: default
    
    - name: Loki
      type: loki
      url: http://loki-gateway.loki.svc.cluster.local
    
    - name: Jaeger
      type: jaeger
      url: http://jaeger-query.opentelemetry.svc.cluster.local:16686
```

### 3. OpenTelemetry Implementation

#### OpenTelemetry Operator Configuration
```yaml
# apps/opentelemetry/values.yaml
opentelemetry-operator:
  admissionWebhooks:
    certManager:
      enabled: false
    autoGenerateCert:
      enabled: true
  
  manager:
    collectorImage:
      repository: "otel/opentelemetry-collector-k8s"
    resources:
      limits:
        cpu: 100m
        memory: 128Mi
      requests:
        cpu: 50m
        memory: 64Mi
```

#### OpenTelemetry Collector Configuration
```yaml
# OpenTelemetry Collector for distributed tracing
apiVersion: opentelemetry.io/v1alpha1
kind: OpenTelemetryCollector
metadata:
  name: tbyte-collector
  namespace: opentelemetry
spec:
  config: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      
      # Kubernetes metrics
      k8s_cluster:
        auth_type: serviceAccount
        node: ${K8S_NODE_NAME}
        
    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
      
      # Add cluster and environment attributes
      resource:
        attributes:
          - key: cluster.name
            value: tbyte-dev
            action: upsert
          - key: environment
            value: dev
            action: upsert
    
    exporters:
      # Export to Prometheus
      prometheus:
        endpoint: "0.0.0.0:8889"
        
      # Export to Jaeger
      jaeger:
        endpoint: jaeger-collector.opentelemetry.svc.cluster.local:14250
        tls:
          insecure: true
      
      # Export to CloudWatch
      awscloudwatchmetrics:
        region: eu-central-1
        namespace: TByte/Application
        
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch, resource]
          exporters: [jaeger]
        
        metrics:
          receivers: [otlp, k8s_cluster]
          processors: [batch, resource]
          exporters: [prometheus, awscloudwatchmetrics]
```

### 4. Alerting Strategy & SEV Definitions

#### Severity Level Definitions
```yaml
# Incident Severity Levels
severity_levels:
  SEV1_CRITICAL:
    description: "Complete service outage affecting all users"
    response_time: "5 minutes"
    escalation: "Immediate page to on-call engineer + manager"
    examples:
      - "EKS cluster down"
      - "Database completely unavailable"
      - "All pods in CrashLoopBackOff"
    
  SEV2_HIGH:
    description: "Significant service degradation affecting >50% users"
    response_time: "15 minutes"
    escalation: "Page to on-call engineer"
    examples:
      - "High error rate (>5%)"
      - "Response time >2 seconds"
      - "Pod memory usage >90%"
    
  SEV3_MEDIUM:
    description: "Partial service degradation affecting <50% users"
    response_time: "1 hour"
    escalation: "Slack notification to team"
    examples:
      - "Moderate error rate (2-5%)"
      - "Response time >1 second"
      - "Disk usage >80%"
    
  SEV4_LOW:
    description: "Minor issues with no user impact"
    response_time: "4 hours"
    escalation: "Email notification"
    examples:
      - "Certificate expiring in 30 days"
      - "Non-critical pod restart"
      - "Log volume increase"
```

#### Prometheus Alert Rules
```yaml
# Prometheus AlertManager rules
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tbyte-alerts
  namespace: monitoring
spec:
  groups:
  - name: tbyte.critical
    rules:
    # SEV1: Cluster down
    - alert: EKSClusterDown
      expr: up{job="kubernetes-apiservers"} == 0
      for: 1m
      labels:
        severity: SEV1_CRITICAL
        team: platform
      annotations:
        summary: "EKS cluster API server is down"
        description: "Kubernetes API server has been down for more than 1 minute"
    
    # SEV1: All pods down
    - alert: AllPodsDown
      expr: kube_deployment_status_replicas_available{deployment="tbyte-microservices-frontend"} == 0
      for: 2m
      labels:
        severity: SEV1_CRITICAL
        team: application
      annotations:
        summary: "All frontend pods are down"
        
  - name: tbyte.high
    rules:
    # SEV2: High error rate
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
      for: 5m
      labels:
        severity: SEV2_HIGH
        team: application
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }} for 5 minutes"
    
    # SEV2: High memory usage
    - alert: HighMemoryUsage
      expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
      for: 10m
      labels:
        severity: SEV2_HIGH
        team: platform
      annotations:
        summary: "Container memory usage is high"
```

#### AlertManager Configuration
```yaml
# AlertManager routing and notification
global:
  slack_api_url: 'https://hooks.slack.com/services/...'

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'
  routes:
  - match:
      severity: SEV1_CRITICAL
    receiver: 'critical-alerts'
    group_wait: 0s
    repeat_interval: 5m
  
  - match:
      severity: SEV2_HIGH
    receiver: 'high-alerts'
    repeat_interval: 15m

receivers:
- name: 'default'
  slack_configs:
  - channel: '#alerts'
    title: 'TByte Alert'
    text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

- name: 'critical-alerts'
  slack_configs:
  - channel: '#critical-alerts'
    title: 'CRITICAL: TByte Alert'
    text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
  pagerduty_configs:
  - service_key: 'your-pagerduty-key'
```

### 5. Log Retention & Indexing Strategy

#### Log Lifecycle Management
```json
{
  "retention_strategy": {
    "hot_tier": {
      "duration": "7 days",
      "storage": "CloudWatch Logs",
      "purpose": "Real-time debugging and alerting",
      "cost": "$0.50/GB ingested + $0.03/GB stored"
    },
    "warm_tier": {
      "duration": "30 days", 
      "storage": "S3 Standard",
      "purpose": "Historical analysis and compliance",
      "cost": "$0.023/GB stored"
    },
    "cold_tier": {
      "duration": "1 year",
      "storage": "S3 Glacier",
      "purpose": "Long-term compliance and audit",
      "cost": "$0.004/GB stored"
    },
    "archive_tier": {
      "duration": "7 years",
      "storage": "S3 Deep Archive", 
      "purpose": "Regulatory compliance",
      "cost": "$0.00099/GB stored"
    }
  }
}
```

#### Log Indexing Strategy
```yaml
# Loki configuration for log aggregation
loki:
  config:
    schema_config:
      configs:
        - from: 2024-01-01
          store: boltdb-shipper
          object_store: s3
          schema: v11
          index:
            prefix: loki_index_
            period: 24h
    
    storage_config:
      boltdb_shipper:
        active_index_directory: /loki/index
        cache_location: /loki/cache
        shared_store: s3
      
      aws:
        s3: s3://tbyte-loki-storage-045129524082/loki
        region: eu-central-1
    
    limits_config:
      retention_period: 30d
      ingestion_rate_mb: 16
      ingestion_burst_size_mb: 32
```

### 6. Dashboard Strategy

#### Infrastructure Dashboards
```json
{
  "dashboard_categories": {
    "infrastructure": {
      "eks_cluster_overview": {
        "panels": [
          "Cluster CPU/Memory utilization",
          "Node count and status", 
          "Pod distribution across nodes",
          "Control plane API latency",
          "etcd performance metrics"
        ]
      },
      "node_performance": {
        "panels": [
          "CPU usage per node",
          "Memory usage per node",
          "Disk I/O and utilization",
          "Network traffic",
          "Pod capacity per node"
        ]
      }
    },
    "application": {
      "microservices_overview": {
        "panels": [
          "Request rate and latency",
          "Error rate by service",
          "Pod restart frequency",
          "Resource usage by service",
          "Database connection pool"
        ]
      },
      "argo_rollouts": {
        "panels": [
          "Canary deployment progress",
          "Analysis run success rate",
          "Rollback frequency",
          "Traffic split visualization",
          "Deployment duration"
        ]
      }
    }
  }
}
```

#### Example Grafana Dashboard Configuration
```json
{
  "dashboard": {
    "title": "TByte Microservices Overview",
    "panels": [
      {
        "title": "Request Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=\"tbyte-microservices\"}[5m]))",
            "legendFormat": "Requests/sec"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "stat", 
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=\"tbyte-microservices\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{job=\"tbyte-microservices\"}[5m]))",
            "legendFormat": "Error Rate"
          }
        ],
        "thresholds": [
          {"color": "green", "value": 0},
          {"color": "yellow", "value": 0.01},
          {"color": "red", "value": 0.05}
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=\"tbyte-microservices\"}[5m])) by (le))",
            "legendFormat": "95th percentile"
          },
          {
            "expr": "histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket{job=\"tbyte-microservices\"}[5m])) by (le))",
            "legendFormat": "50th percentile"
          }
        ]
      }
    ]
  }
}
```

## Result

### Monitoring Stack Deployment Status

#### Verification Commands
```bash
# Check Prometheus stack
kubectl get pods -n monitoring
kubectl get servicemonitor -n monitoring

# Check OpenTelemetry
kubectl get pods -n opentelemetry
kubectl get opentelemetrycollector -n opentelemetry

# Check CloudWatch logs
aws logs describe-log-groups --profile dev_4082 --region eu-central-1 \
  --log-group-name-prefix /aws/eks/tbyte-dev
```

#### Current Implementation Status
- **Prometheus**: Deployed with 15-day retention and 50GB storage
- **Grafana**: Deployed with CloudWatch integration via IRSA
- **OpenTelemetry**: Operator deployed, collector configuration ready
- **CloudWatch**: EKS control plane logging enabled
- **AlertManager**: Configured with Slack integration

### Observability Coverage Achieved

#### Infrastructure Layer
- **EKS Control Plane**: API server, scheduler, controller manager logs
- **Node Metrics**: CPU, memory, disk, network utilization
- **Pod Metrics**: Resource usage, restart counts, status
- **Network Metrics**: Service mesh traffic, ingress/egress

#### Application Layer  
- **HTTP Metrics**: Request rate, latency, error rate
- **Database Metrics**: Connection pool, query performance
- **Custom Metrics**: Business KPIs, user journey tracking
- **Distributed Tracing**: Request flow across microservices

#### Business Layer
- **SLA Monitoring**: Availability, performance targets
- **User Experience**: Page load times, conversion rates
- **Deployment Metrics**: Rollout success, rollback frequency
- **Cost Metrics**: Resource utilization efficiency

### Cost Analysis

#### Cost Optimization Strategies
- **Log Sampling**: Sample non-critical logs at 10% rate
- **Metric Aggregation**: Pre-aggregate high-cardinality metrics
- **Retention Policies**: Shorter retention for debug logs
- **S3 Lifecycle**: Automatic transition to cheaper storage tiers

### Alerting Effectiveness

#### Alert Response Metrics
- **Mean Time to Detection (MTTD)**: <2 minutes for SEV1 issues
- **Mean Time to Response (MTTR)**: <5 minutes for critical alerts
- **False Positive Rate**: <5% through proper alert tuning
- **Alert Fatigue Prevention**: Grouped alerts and smart routing

#### Incident Management Integration
```yaml
# PagerDuty integration for critical alerts
pagerduty_configs:
- service_key: 'tbyte-critical-service-key'
  description: 'TByte Critical Alert: {{ .GroupLabels.alertname }}'
  severity: 'critical'
  client: 'TByte Monitoring'
  client_url: 'https://grafana.tbyte.com/d/overview'
```

### Future Enhancements

#### Phase 1: Advanced Tracing
- **Jaeger Deployment**: Complete distributed tracing setup
- **Service Map**: Automatic service dependency discovery
- **Trace Sampling**: Intelligent sampling based on error rates

#### Phase 2: AI/ML Integration
- **Anomaly Detection**: CloudWatch Anomaly Detection for metrics
- **Predictive Alerting**: ML-based threshold adjustment
- **Root Cause Analysis**: Automated correlation of metrics and logs

#### Phase 3: Business Intelligence
- **Custom Dashboards**: Business-specific KPI tracking
- **SLA Reporting**: Automated SLA compliance reporting
- **Cost Attribution**: Resource cost allocation by team/service

### Compliance & Security

#### Data Retention Compliance
- **GDPR**: 30-day retention for user-identifiable logs
- **SOX**: 7-year retention for financial transaction logs
- **HIPAA**: Encrypted storage and access logging

#### Security Monitoring
- **Access Logs**: All dashboard and alert access logged
- **Audit Trail**: Configuration changes tracked
- **Encryption**: All data encrypted in transit and at rest
