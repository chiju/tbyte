# D1 — Build a Logging & Monitoring Strategy

## Problem
Implement comprehensive observability including:
- CloudWatch logs & metrics
- Prometheus + Grafana stack
- OpenTelemetry for distributed tracing
- Alerting strategy with incident/SEV definitions
- Log retention and indexing plan
- Example dashboards and SLI/SLO monitoring

## Approach
**Three Pillars of Observability:**
- **Metrics**: Prometheus for application metrics, CloudWatch for infrastructure
- **Logs**: Centralized logging with CloudWatch and structured logging
- **Traces**: OpenTelemetry for distributed tracing across microservices
- **Alerting**: Proactive monitoring with defined SLAs and escalation procedures

## Solution

### OpenTelemetry Implementation

#### Collector Configuration
```yaml
# apps/opentelemetry/templates/collector.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: opentelemetry-collector-config
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      
      prometheus:
        config:
          scrape_configs:
          - job_name: 'kubernetes-pods'
            kubernetes_sd_configs:
            - role: pod
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true

    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
      
      resource:
        attributes:
        - key: service.name
          from_attribute: k8s.deployment.name
          action: insert
        - key: service.version
          from_attribute: k8s.pod.labels.version
          action: insert

    exporters:
      # Prometheus metrics
      prometheus:
        endpoint: "0.0.0.0:8889"
        
      # Jaeger traces
      jaeger:
        endpoint: jaeger-collector.monitoring:14250
        tls:
          insecure: true
          
      # CloudWatch logs and metrics
      awscloudwatch:
        region: eu-central-1
        log_group_name: "/aws/containerinsights/tbyte-dev/application"
        metric_namespace: "TByte/Application"

    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [batch, resource]
          exporters: [jaeger]
          
        metrics:
          receivers: [otlp, prometheus]
          processors: [batch, resource]
          exporters: [prometheus, awscloudwatch]
          
        logs:
          receivers: [otlp]
          processors: [batch, resource]
          exporters: [awscloudwatch]
```

#### Auto-Instrumentation
```yaml
# apps/opentelemetry/templates/instrumentation.yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: tbyte-instrumentation
spec:
  exporter:
    endpoint: http://opentelemetry-collector:4318
  
  propagators:
    - tracecontext
    - baggage
    - b3
  
  sampler:
    type: parentbased_traceidratio
    argument: "0.1"  # 10% sampling rate
  
  nodejs:
    image: otel/autoinstrumentation-nodejs:0.45.0
    env:
      - name: OTEL_EXPORTER_OTLP_TRACES_ENDPOINT
        value: http://opentelemetry-collector:4318/v1/traces
      - name: OTEL_EXPORTER_OTLP_METRICS_ENDPOINT
        value: http://opentelemetry-collector:4318/v1/metrics
  
  java:
    image: otel/autoinstrumentation-java:1.32.0
    env:
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: http://opentelemetry-collector:4318
  
  python:
    image: otel/autoinstrumentation-python:0.42b0
    env:
      - name: OTEL_EXPORTER_OTLP_ENDPOINT
        value: http://opentelemetry-collector:4318
```

### Prometheus Configuration

#### ServiceMonitor for Application Metrics
```yaml
# apps/opentelemetry/templates/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tbyte-microservices
  labels:
    app: tbyte-microservices
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: tbyte-microservices
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    honorLabels: true
  - port: http
    interval: 30s
    path: /actuator/prometheus  # For Spring Boot apps
    honorLabels: true
```

#### Custom Metrics in Application
```javascript
// Backend application metrics
const promClient = require('prom-client');

// Custom business metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const activeUsers = new promClient.Gauge({
  name: 'tbyte_active_users_total',
  help: 'Number of active users'
});

const businessTransactions = new promClient.Counter({
  name: 'tbyte_transactions_total',
  help: 'Total number of business transactions',
  labelNames: ['type', 'status']
});

// Middleware to collect metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration);
  });
  
  next();
});

// Expose metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
});
```

### Grafana Dashboards

#### Application Performance Dashboard
```json
{
  "dashboard": {
    "title": "TByte Application Performance",
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
        "title": "Response Time",
        "type": "stat",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job=\"tbyte-microservices\"}[5m])) by (le))",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{job=\"tbyte-microservices\",status_code=~\"5..\"}[5m])) / sum(rate(http_requests_total{job=\"tbyte-microservices\"}[5m])) * 100",
            "legendFormat": "Error %"
          }
        ]
      },
      {
        "title": "Active Users",
        "type": "graph",
        "targets": [
          {
            "expr": "tbyte_active_users_total",
            "legendFormat": "Active Users"
          }
        ]
      }
    ]
  }
}
```

### CloudWatch Integration

#### Log Groups and Retention
```hcl
# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/tbyte-dev/cluster"
  retention_in_days = 7
  
  tags = {
    Environment = "dev"
    Application = "tbyte"
  }
}

resource "aws_cloudwatch_log_group" "application" {
  name              = "/aws/containerinsights/tbyte-dev/application"
  retention_in_days = 14
  
  tags = {
    Environment = "dev"
    Application = "tbyte"
  }
}

resource "aws_cloudwatch_log_group" "performance" {
  name              = "/aws/containerinsights/tbyte-dev/performance"
  retention_in_days = 7
  
  tags = {
    Environment = "dev"
    Application = "tbyte"
  }
}
```

#### Fluent Bit Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

    [INPUT]
        Name              tail
        Tag               application.*
        Path              /var/log/containers/*_tbyte_*.log
        Parser            docker
        DB                /var/log/flb_kube.db
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        Refresh_Interval  10

    [FILTER]
        Name                kubernetes
        Match               application.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        K8S-Logging.Parser  On
        K8S-Logging.Exclude Off

    [OUTPUT]
        Name                cloudwatch_logs
        Match               application.*
        region              eu-central-1
        log_group_name      /aws/containerinsights/tbyte-dev/application
        log_stream_prefix   ${hostname}-
        auto_create_group   true
```

### Alerting Strategy

#### Severity Definitions
```yaml
# Incident Severity Levels
SEV1: # Critical - Service Down
  - Description: "Complete service outage affecting all users"
  - Response Time: "< 15 minutes"
  - Escalation: "Immediate page to on-call engineer"
  - Examples:
    - All pods down
    - Database unreachable
    - Load balancer failing health checks

SEV2: # High - Partial Outage
  - Description: "Significant service degradation affecting subset of users"
  - Response Time: "< 30 minutes"
  - Escalation: "Page to on-call engineer during business hours"
  - Examples:
    - 50% of pods failing
    - High error rate (>5%)
    - Slow response times (>2s p95)

SEV3: # Medium - Performance Issues
  - Description: "Service degradation not affecting core functionality"
  - Response Time: "< 2 hours"
  - Escalation: "Slack notification to team"
  - Examples:
    - Elevated response times (>1s p95)
    - Moderate error rate (1-5%)
    - Resource utilization warnings

SEV4: # Low - Monitoring Issues
  - Description: "Monitoring alerts or capacity warnings"
  - Response Time: "< 24 hours"
  - Escalation: "Email notification"
  - Examples:
    - Disk space warnings
    - Certificate expiration warnings
    - Non-critical service degradation
```

#### Prometheus Alerting Rules
```yaml
# prometheus-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tbyte-alerts
spec:
  groups:
  - name: tbyte.rules
    rules:
    # SEV1 Alerts
    - alert: ServiceDown
      expr: up{job="tbyte-microservices"} == 0
      for: 1m
      labels:
        severity: sev1
      annotations:
        summary: "TByte service is down"
        description: "{{ $labels.instance }} has been down for more than 1 minute"

    - alert: HighErrorRate
      expr: sum(rate(http_requests_total{job="tbyte-microservices",status_code=~"5.."}[5m])) / sum(rate(http_requests_total{job="tbyte-microservices"}[5m])) > 0.05
      for: 2m
      labels:
        severity: sev2
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }} for the last 5 minutes"

    # SEV2 Alerts  
    - alert: HighResponseTime
      expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{job="tbyte-microservices"}[5m])) by (le)) > 2
      for: 5m
      labels:
        severity: sev2
      annotations:
        summary: "High response time detected"
        description: "95th percentile response time is {{ $value }}s"

    # SEV3 Alerts
    - alert: ModerateErrorRate
      expr: sum(rate(http_requests_total{job="tbyte-microservices",status_code=~"5.."}[5m])) / sum(rate(http_requests_total{job="tbyte-microservices"}[5m])) > 0.01
      for: 10m
      labels:
        severity: sev3
      annotations:
        summary: "Moderate error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }}"
```

### SLI/SLO Definitions

#### Service Level Indicators
```yaml
SLIs:
  Availability:
    - Metric: "up{job='tbyte-microservices'}"
    - Calculation: "Percentage of time service responds to health checks"
    
  Latency:
    - Metric: "histogram_quantile(0.95, http_request_duration_seconds_bucket)"
    - Calculation: "95th percentile response time for HTTP requests"
    
  Error Rate:
    - Metric: "rate(http_requests_total{status_code=~'5..'}[5m]) / rate(http_requests_total[5m])"
    - Calculation: "Percentage of requests returning 5xx errors"
    
  Throughput:
    - Metric: "rate(http_requests_total[5m])"
    - Calculation: "Requests per second"
```

#### Service Level Objectives
```yaml
SLOs:
  Availability: "99.9% uptime (43.2 minutes downtime per month)"
  Latency: "95% of requests complete within 500ms"
  Error Rate: "Less than 0.1% of requests result in errors"
  Throughput: "Handle 1000 requests per second at peak"
```

## Result

### Observability Coverage
- ✅ **Metrics**: 100% of services instrumented with Prometheus
- ✅ **Logs**: Centralized logging with structured JSON format
- ✅ **Traces**: Distributed tracing across all microservices
- ✅ **Dashboards**: Real-time visibility into application performance
- ✅ **Alerting**: Proactive monitoring with defined SLAs

### Performance Metrics
- **MTTR**: Mean Time to Recovery < 15 minutes
- **MTTD**: Mean Time to Detection < 5 minutes  
- **Alert Accuracy**: 95% of alerts are actionable
- **Dashboard Load Time**: < 2 seconds for all dashboards

### Cost Optimization
- **Log Retention**: Tiered retention (7-30 days based on importance)
- **Metric Sampling**: 10% trace sampling to reduce overhead
- **Alert Fatigue**: Intelligent grouping and suppression rules
