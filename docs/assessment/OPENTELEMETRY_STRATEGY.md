# OpenTelemetry Implementation Strategy

## **Current Observability Stack**
- ✅ **Metrics**: Prometheus + Grafana
- ✅ **Logs**: Loki + Promtail  
- ❌ **Traces**: Not implemented (OpenTelemetry gap)

## **OpenTelemetry Integration Plan**

### **What OpenTelemetry Adds**
- **Distributed Tracing**: Request flow across microservices
- **Unified Observability**: Single standard for metrics, logs, traces
- **Vendor Neutral**: Works with any backend (Jaeger, Zipkin, etc.)

### **Architecture**
```
Application → OpenTelemetry SDK → OTEL Collector → Jaeger/Tempo
                                                 → Prometheus  
                                                 → Loki
```

### **Implementation Approach**

#### **1. OpenTelemetry Collector**
```yaml
# apps/opentelemetry/values.yaml
mode: deployment
image:
  repository: otel/opentelemetry-collector-contrib
  tag: latest

config:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317
        http:
          endpoint: 0.0.0.0:4318
    
  processors:
    batch:
    
  exporters:
    # Traces to Jaeger
    jaeger:
      endpoint: jaeger-collector:14250
      tls:
        insecure: true
    
    # Metrics to Prometheus
    prometheus:
      endpoint: "0.0.0.0:8889"
    
    # Logs to Loki
    loki:
      endpoint: http://loki:3100/loki/api/v1/push

  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [batch]
        exporters: [jaeger]
      
      metrics:
        receivers: [otlp]
        processors: [batch]
        exporters: [prometheus]
        
      logs:
        receivers: [otlp]
        processors: [batch]
        exporters: [loki]
```

#### **2. Jaeger for Distributed Tracing**
```yaml
# apps/jaeger/values.yaml
provisionDataStore:
  cassandra: false
  elasticsearch: true

elasticsearch:
  replicas: 1
  minimumMasterNodes: 1

agent:
  enabled: false  # Using OTEL Collector instead

collector:
  enabled: true
  service:
    type: ClusterIP

query:
  enabled: true
  service:
    type: LoadBalancer
```

#### **3. Application Instrumentation**

**Backend (Node.js):**
```javascript
// backend/tracing.js
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-otlp-http');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'http://otel-collector:4318/v1/traces',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

**Frontend (Browser):**
```javascript
// frontend/tracing.js
import { WebTracerProvider } from '@opentelemetry/sdk-trace-web';
import { OTLPTraceExporter } from '@opentelemetry/exporter-otlp-http';
import { getWebAutoInstrumentations } from '@opentelemetry/auto-instrumentations-web';

const provider = new WebTracerProvider();
provider.addSpanProcessor(
  new BatchSpanProcessor(
    new OTLPTraceExporter({
      url: 'http://tbyte.local/api/traces',
    })
  )
);

registerInstrumentations({
  instrumentations: [getWebAutoInstrumentations()],
});
```

### **Deployment Strategy**

#### **Phase 1: Infrastructure (30 minutes)**
```bash
# Deploy OpenTelemetry Collector
helm install otel-collector open-telemetry/opentelemetry-collector \
  -f apps/opentelemetry/values.yaml -n monitoring

# Deploy Jaeger
helm install jaeger jaegertracing/jaeger \
  -f apps/jaeger/values.yaml -n monitoring
```

#### **Phase 2: Application Integration (1 hour)**
```bash
# Add tracing to backend
npm install @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node

# Add tracing to frontend  
npm install @opentelemetry/sdk-trace-web @opentelemetry/auto-instrumentations-web

# Update Docker images with tracing
docker build -t tbyte-backend:otel .
docker build -t tbyte-frontend:otel .
```

#### **Phase 3: Visualization (15 minutes)**
```bash
# Access Jaeger UI
kubectl port-forward svc/jaeger-query 16686:16686 -n monitoring
open http://localhost:16686

# Add Jaeger to Grafana
# Data source: http://jaeger-query:16686
```

### **Benefits of OpenTelemetry**

#### **Distributed Tracing Examples**
```
Request: GET /api/users
├── Frontend (span: user-request) 
├── Istio Gateway (span: gateway-routing)
├── Backend (span: api-handler)
├── Database Query (span: postgres-query)
└── Response (span: response-serialization)
```

#### **Performance Insights**
- **Latency Breakdown**: Which service is slow?
- **Error Correlation**: Trace errors across services
- **Dependency Mapping**: Service interaction visualization
- **Bottleneck Identification**: Database vs API vs network

### **Current Status vs OpenTelemetry**

| Feature | Current | With OpenTelemetry |
|---------|---------|-------------------|
| **Metrics** | ✅ Prometheus | ✅ Prometheus + OTEL |
| **Logs** | ✅ Loki | ✅ Loki + structured |
| **Traces** | ❌ None | ✅ Jaeger/Tempo |
| **Correlation** | ❌ Manual | ✅ Automatic |
| **Service Map** | ❌ None | ✅ Auto-generated |

### **Implementation Decision**

#### **Current Assessment Approach**
- **Focus**: Core functionality over advanced observability
- **Rationale**: Demonstrate working application first
- **Trade-off**: Skip OpenTelemetry to prioritize other requirements

#### **Production Recommendation**
- **Implement OpenTelemetry** for enterprise environments
- **Start with**: Automatic instrumentation (minimal code changes)
- **Expand to**: Custom spans and metrics as needed
- **Timeline**: 2-3 days for full implementation

### **Quick Implementation (If Time Permits)**

```bash
# 1. Deploy Jaeger (5 minutes)
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/crds/jaegertracing.io_jaegers_crd.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/service_account.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/role.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/role_binding.yaml
kubectl apply -f https://raw.githubusercontent.com/jaegertracing/jaeger-operator/main/deploy/operator.yaml

# 2. Simple Jaeger instance
kubectl apply -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: simplest
  namespace: monitoring
EOF

# 3. Access Jaeger UI
kubectl port-forward svc/simplest-query 16686:16686 -n monitoring
```

## **Conclusion**

OpenTelemetry would provide **complete observability** but is **not critical** for demonstrating core DevOps capabilities. Current monitoring stack (Prometheus + Grafana + Loki) covers essential observability needs for the assessment.
