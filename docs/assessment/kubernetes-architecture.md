# Kubernetes Architecture - TByte Microservices Platform

## Application Architecture

```mermaid
graph TB
    subgraph "External Traffic"
        Users[End Users]
        Internet[Internet]
    end
    
    subgraph "AWS Load Balancer"
        ALB[Application Load Balancer<br/>tbyte.local]
    end
    
    subgraph "EKS Cluster - tbyte-dev"
        subgraph "Ingress Layer"
            Ingress[Ingress Controller<br/>nginx-ingress]
        end
        
        subgraph "Application Namespace"
            subgraph "Frontend Tier"
                FrontendSvc[Frontend Service<br/>ClusterIP]
                FrontendPods[Frontend Pods<br/>React App<br/>Replicas: 2-5]
            end
            
            subgraph "Backend Tier"
                BackendSvc[Backend Service<br/>ClusterIP]
                BackendPods[Backend Pods<br/>Node.js API<br/>Replicas: 2-5]
            end
            
            subgraph "Database Tier"
                PostgresSvc[PostgreSQL Service<br/>ClusterIP]
                PostgresPods[PostgreSQL Pods<br/>StatefulSet<br/>Replicas: 1]
                PostgresPVC[Persistent Volume<br/>EBS gp3]
            end
        end
        
        subgraph "System Namespace - argocd"
            ArgoCDServer[ArgoCD Server]
            ArgoCDRepo[ArgoCD Repo Server]
            ArgoCDController[ArgoCD Controller]
        end
        
        subgraph "System Namespace - monitoring"
            Prometheus[Prometheus Server<br/>Metrics Collection]
            Grafana[Grafana Dashboard<br/>Visualization]
            AlertManager[Alert Manager<br/>Notifications]
        end
        
        subgraph "System Namespace - logging"
            Loki[Loki<br/>Log Aggregation]
            Promtail[Promtail<br/>Log Collection<br/>DaemonSet]
        end
        
        subgraph "System Namespace - karpenter"
            KarpenterController[Karpenter Controller<br/>Node Autoscaling]
        end
        
        subgraph "System Namespace - keda"
            KEDAOperator[KEDA Operator<br/>Pod Autoscaling]
        end
    end
    
    subgraph "AWS RDS"
        RDSPostgres[RDS PostgreSQL<br/>Multi-AZ<br/>Encrypted]
    end
    
    subgraph "AWS CloudWatch"
        CloudWatchLogs[CloudWatch Logs]
        CloudWatchMetrics[CloudWatch Metrics]
    end
    
    %% Traffic Flow
    Users --> Internet
    Internet --> ALB
    ALB --> Ingress
    Ingress --> FrontendSvc
    FrontendSvc --> FrontendPods
    FrontendPods --> BackendSvc
    BackendSvc --> BackendPods
    BackendPods --> RDSPostgres
    
    %% GitOps Flow
    ArgoCDServer --> FrontendPods
    ArgoCDServer --> BackendPods
    ArgoCDController --> ArgoCDServer
    
    %% Monitoring Flow
    Promtail --> Loki
    Prometheus --> Grafana
    Prometheus --> AlertManager
    Grafana --> CloudWatchMetrics
    
    %% Autoscaling
    KEDAOperator --> FrontendPods
    KEDAOperator --> BackendPods
    KarpenterController --> EKSNodes[EKS Nodes]
    
    %% Storage
    PostgresPods --> PostgresPVC
    
    %% Logging
    FrontendPods --> CloudWatchLogs
    BackendPods --> CloudWatchLogs
    
    classDef frontend fill:#61DAFB,stroke:#fff,stroke-width:2px,color:#000
    classDef backend fill:#68A063,stroke:#fff,stroke-width:2px,color:#fff
    classDef database fill:#336791,stroke:#fff,stroke-width:2px,color:#fff
    classDef system fill:#FF6B6B,stroke:#fff,stroke-width:2px,color:#fff
    classDef aws fill:#FF9900,stroke:#232F3E,stroke-width:2px,color:#fff
    classDef external fill:#2E8B57,stroke:#fff,stroke-width:2px,color:#fff
    
    class FrontendSvc,FrontendPods frontend
    class BackendSvc,BackendPods backend
    class PostgresSvc,PostgresPods,PostgresPVC database
    class ArgoCDServer,ArgoCDRepo,ArgoCDController,Prometheus,Grafana,AlertManager,Loki,Promtail,KarpenterController,KEDAOperator system
    class ALB,RDSPostgres,CloudWatchLogs,CloudWatchMetrics aws
    class Users,Internet,Ingress external
```

## Pod Security & Resource Management

```mermaid
graph TB
    subgraph "Pod Security Context"
        subgraph "Security Standards"
            NonRoot[runAsNonUser: true<br/>runAsUser: 1000]
            ReadOnlyFS[readOnlyRootFilesystem: true]
            NoPrivileged[allowPrivilegeEscalation: false]
            Capabilities[drop: ALL<br/>add: NET_BIND_SERVICE]
        end
        
        subgraph "Resource Limits"
            CPULimits[CPU Limits<br/>requests: 100m<br/>limits: 500m]
            MemoryLimits[Memory Limits<br/>requests: 128Mi<br/>limits: 512Mi]
            EphemeralStorage[Ephemeral Storage<br/>requests: 1Gi<br/>limits: 2Gi]
        end
        
        subgraph "Health Checks"
            LivenessProbe[Liveness Probe<br/>HTTP /health<br/>initialDelay: 30s]
            ReadinessProbe[Readiness Probe<br/>HTTP /ready<br/>initialDelay: 5s]
            StartupProbe[Startup Probe<br/>HTTP /startup<br/>failureThreshold: 30]
        end
    end
    
    subgraph "Autoscaling Configuration"
        subgraph "Horizontal Pod Autoscaler"
            HPACPUTarget[CPU Target: 70%]
            HPAMemoryTarget[Memory Target: 80%]
            HPAMinReplicas[Min Replicas: 2]
            HPAMaxReplicas[Max Replicas: 10]
        end
        
        subgraph "KEDA Scaling"
            KEDACPUScaler[CPU Scaler<br/>Target: 70%]
            KEDAMemoryScaler[Memory Scaler<br/>Target: 80%]
            KEDACustomMetrics[Custom Metrics<br/>Prometheus queries]
        end
        
        subgraph "Pod Disruption Budget"
            PDBMinAvailable[minAvailable: 50%]
            PDBMaxUnavailable[maxUnavailable: 1]
        end
    end
    
    subgraph "Network Policies"
        subgraph "Ingress Rules"
            AllowIngress[Allow from Ingress<br/>Port 80, 443]
            AllowMonitoring[Allow from Monitoring<br/>Port 8080, 9090]
        end
        
        subgraph "Egress Rules"
            AllowDNS[Allow DNS<br/>Port 53]
            AllowHTTPS[Allow HTTPS<br/>Port 443]
            AllowDatabase[Allow Database<br/>Port 5432]
        end
        
        subgraph "Deny Rules"
            DenyDefault[Deny All Other Traffic]
        end
    end
    
    classDef security fill:#DD344C,stroke:#fff,stroke-width:2px,color:#fff
    classDef resources fill:#4A90E2,stroke:#fff,stroke-width:2px,color:#fff
    classDef scaling fill:#7B68EE,stroke:#fff,stroke-width:2px,color:#fff
    classDef network fill:#2E8B57,stroke:#fff,stroke-width:2px,color:#fff
    
    class NonRoot,ReadOnlyFS,NoPrivileged,Capabilities security
    class CPULimits,MemoryLimits,EphemeralStorage,LivenessProbe,ReadinessProbe,StartupProbe resources
    class HPACPUTarget,HPAMemoryTarget,HPAMinReplicas,HPAMaxReplicas,KEDACPUScaler,KEDAMemoryScaler,KEDACustomMetrics,PDBMinAvailable,PDBMaxUnavailable scaling
    class AllowIngress,AllowMonitoring,AllowDNS,AllowHTTPS,AllowDatabase,DenyDefault network
```

## GitOps Deployment Flow

```mermaid
graph LR
    subgraph "Source Control"
        GitRepo[Git Repository<br/>chiju/tbyte]
        AppManifests[Application Manifests<br/>apps/]
        ArgoApps[ArgoCD Applications<br/>argocd-apps/]
    end
    
    subgraph "CI/CD Pipeline"
        GitHubActions[GitHub Actions]
        TerraformPlan[Terraform Plan]
        TerraformApply[Terraform Apply]
        UpdateConfigs[Update App Configs]
    end
    
    subgraph "ArgoCD"
        ArgoCDController[ArgoCD Controller]
        AppOfApps[App of Apps Pattern]
        SyncWaves[Sync Waves<br/>1. Infrastructure<br/>2. Applications<br/>3. Configuration]
    end
    
    subgraph "Kubernetes Cluster"
        subgraph "Core Apps (Wave 1)"
            Karpenter[Karpenter]
            KEDA[KEDA]
            CSIDriver[Secrets Store CSI]
        end
        
        subgraph "Platform Apps (Wave 2)"
            Monitoring[Prometheus Stack]
            Logging[Loki Stack]
            Vault[HashiCorp Vault]
        end
        
        subgraph "Business Apps (Wave 3)"
            Frontend[Frontend App]
            Backend[Backend App]
            Database[PostgreSQL]
        end
    end
    
    GitRepo --> GitHubActions
    GitHubActions --> TerraformPlan
    TerraformPlan --> TerraformApply
    TerraformApply --> UpdateConfigs
    
    UpdateConfigs --> ArgoCDController
    ArgoCDController --> AppOfApps
    AppOfApps --> SyncWaves
    
    SyncWaves --> Karpenter
    SyncWaves --> KEDA
    SyncWaves --> CSIDriver
    SyncWaves --> Monitoring
    SyncWaves --> Logging
    SyncWaves --> Vault
    SyncWaves --> Frontend
    SyncWaves --> Backend
    SyncWaves --> Database
    
    classDef source fill:#24292E,stroke:#fff,stroke-width:2px,color:#fff
    classDef cicd fill:#2E8B57,stroke:#fff,stroke-width:2px,color:#fff
    classDef argocd fill:#EF7B4D,stroke:#fff,stroke-width:2px,color:#fff
    classDef core fill:#FF6B6B,stroke:#fff,stroke-width:2px,color:#fff
    classDef platform fill:#4ECDC4,stroke:#fff,stroke-width:2px,color:#fff
    classDef business fill:#45B7D1,stroke:#fff,stroke-width:2px,color:#fff
    
    class GitRepo,AppManifests,ArgoApps source
    class GitHubActions,TerraformPlan,TerraformApply,UpdateConfigs cicd
    class ArgoCDController,AppOfApps,SyncWaves argocd
    class Karpenter,KEDA,CSIDriver core
    class Monitoring,Logging,Vault platform
    class Frontend,Backend,Database business
```

## Secrets Management Architecture

```mermaid
graph TB
    subgraph "Secrets Sources"
        GitHubSecrets[GitHub Secrets<br/>AWS Role ARNs]
        AWSSecrets[AWS Secrets Manager<br/>Database credentials]
        VaultSecrets[HashiCorp Vault<br/>Application secrets]
    end
    
    subgraph "Kubernetes Secrets Integration"
        subgraph "CSI Driver"
            CSIDriver[Secrets Store CSI Driver]
            VaultProvider[Vault CSI Provider]
            AWSProvider[AWS CSI Provider]
        end
        
        subgraph "Service Accounts"
            AppSA[Application Service Account]
            VaultSA[Vault Service Account]
            IRSA[IAM Roles for Service Accounts]
        end
        
        subgraph "Secret Consumption"
            SecretVolumes[CSI Secret Volumes<br/>/mnt/secrets/]
            EnvVars[Environment Variables<br/>from mounted files]
            ConfigMaps[ConfigMaps<br/>Non-sensitive config]
        end
    end
    
    subgraph "Applications"
        Frontend[Frontend Pods<br/>API Keys from Vault]
        Backend[Backend Pods<br/>DB credentials from AWS]
        Monitoring[Monitoring Stack<br/>CloudWatch credentials]
    end
    
    GitHubSecrets --> IRSA
    AWSSecrets --> AWSProvider
    VaultSecrets --> VaultProvider
    
    AWSProvider --> CSIDriver
    VaultProvider --> CSIDriver
    
    CSIDriver --> SecretVolumes
    SecretVolumes --> EnvVars
    
    AppSA --> IRSA
    VaultSA --> VaultProvider
    
    EnvVars --> Frontend
    EnvVars --> Backend
    EnvVars --> Monitoring
    
    ConfigMaps --> Frontend
    ConfigMaps --> Backend
    
    classDef secrets fill:#DD344C,stroke:#fff,stroke-width:2px,color:#fff
    classDef k8s fill:#326CE5,stroke:#fff,stroke-width:2px,color:#fff
    classDef apps fill:#2E8B57,stroke:#fff,stroke-width:2px,color:#fff
    
    class GitHubSecrets,AWSSecrets,VaultSecrets,CSIDriver,VaultProvider,AWSProvider,SecretVolumes,EnvVars secrets
    class AppSA,VaultSA,IRSA,ConfigMaps k8s
    class Frontend,Backend,Monitoring apps
```

## Monitoring & Observability Stack

```mermaid
graph TB
    subgraph "Data Sources"
        subgraph "Metrics"
            K8sMetrics[Kubernetes Metrics<br/>kube-state-metrics]
            NodeMetrics[Node Metrics<br/>node-exporter]
            AppMetrics[Application Metrics<br/>Custom /metrics endpoints]
            AWSMetrics[AWS CloudWatch<br/>EKS, RDS, ALB metrics]
        end
        
        subgraph "Logs"
            ContainerLogs[Container Logs<br/>stdout/stderr]
            K8sEvents[Kubernetes Events<br/>event-exporter]
            AWSLogs[AWS CloudWatch Logs<br/>EKS control plane]
        end
        
        subgraph "Traces"
            AppTraces[Application Traces<br/>OpenTelemetry]
            ServiceMesh[Service Mesh Traces<br/>Istio (future)]
        end
    end
    
    subgraph "Collection Layer"
        Prometheus[Prometheus<br/>Metrics scraping<br/>15 days retention]
        Promtail[Promtail DaemonSet<br/>Log collection]
        OTelCollector[OpenTelemetry Collector<br/>Trace collection]
    end
    
    subgraph "Storage Layer"
        PrometheusStorage[Prometheus Storage<br/>Local SSD + EBS]
        LokiStorage[Loki Storage<br/>S3 backend]
        JaegerStorage[Jaeger Storage<br/>Elasticsearch]
    end
    
    subgraph "Visualization Layer"
        Grafana[Grafana Dashboards<br/>Metrics + Logs + Traces]
        AlertManager[Alert Manager<br/>Slack notifications]
        
        subgraph "Dashboards"
            ClusterDash[EKS Cluster Overview]
            AppDash[Application Performance]
            CostDash[Cost Optimization]
            SecurityDash[Security Monitoring]
        end
    end
    
    subgraph "External Integrations"
        Slack[Slack Notifications]
        PagerDuty[PagerDuty (future)]
        Email[Email Alerts]
    end
    
    %% Metrics Flow
    K8sMetrics --> Prometheus
    NodeMetrics --> Prometheus
    AppMetrics --> Prometheus
    AWSMetrics --> Grafana
    
    %% Logs Flow
    ContainerLogs --> Promtail
    K8sEvents --> Promtail
    AWSLogs --> Grafana
    
    %% Traces Flow
    AppTraces --> OTelCollector
    ServiceMesh --> OTelCollector
    
    %% Storage
    Prometheus --> PrometheusStorage
    Promtail --> LokiStorage
    OTelCollector --> JaegerStorage
    
    %% Visualization
    PrometheusStorage --> Grafana
    LokiStorage --> Grafana
    JaegerStorage --> Grafana
    
    Prometheus --> AlertManager
    AlertManager --> Slack
    AlertManager --> Email
    
    Grafana --> ClusterDash
    Grafana --> AppDash
    Grafana --> CostDash
    Grafana --> SecurityDash
    
    classDef metrics fill:#E6522C,stroke:#fff,stroke-width:2px,color:#fff
    classDef logs fill:#F46800,stroke:#fff,stroke-width:2px,color:#fff
    classDef traces fill:#9C27B0,stroke:#fff,stroke-width:2px,color:#fff
    classDef storage fill:#4A90E2,stroke:#fff,stroke-width:2px,color:#fff
    classDef viz fill:#2E8B57,stroke:#fff,stroke-width:2px,color:#fff
    classDef external fill:#FF6B6B,stroke:#fff,stroke-width:2px,color:#fff
    
    class K8sMetrics,NodeMetrics,AppMetrics,AWSMetrics,Prometheus,PrometheusStorage metrics
    class ContainerLogs,K8sEvents,AWSLogs,Promtail,LokiStorage logs
    class AppTraces,ServiceMesh,OTelCollector,JaegerStorage traces
    class PrometheusStorage,LokiStorage,JaegerStorage storage
    class Grafana,AlertManager,ClusterDash,AppDash,CostDash,SecurityDash viz
    class Slack,PagerDuty,Email external
```

## Deployment Strategies

### Rolling Deployment (Current)
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 25%
    maxSurge: 25%
```

### Blue/Green Deployment (Future)
```mermaid
graph LR
    subgraph "Blue/Green Strategy"
        ALB[Application Load Balancer]
        
        subgraph "Blue Environment (Current)"
            BlueService[Blue Service v1.0]
            BluePods[Blue Pods v1.0<br/>100% traffic]
        end
        
        subgraph "Green Environment (New)"
            GreenService[Green Service v1.1]
            GreenPods[Green Pods v1.1<br/>0% traffic]
        end
        
        subgraph "Traffic Switch"
            TrafficSplit[Traffic Splitting<br/>0% → 100%]
        end
    end
    
    ALB --> BlueService
    ALB -.-> GreenService
    BlueService --> BluePods
    GreenService --> GreenPods
    TrafficSplit --> ALB
    
    classDef current fill:#2E8B57,stroke:#fff,stroke-width:2px,color:#fff
    classDef new fill:#4A90E2,stroke:#fff,stroke-width:2px,color:#fff
    classDef control fill:#FF6B6B,stroke:#fff,stroke-width:2px,color:#fff
    
    class BlueService,BluePods current
    class GreenService,GreenPods new
    class ALB,TrafficSplit control
```

### Canary Deployment (Future)
```mermaid
graph LR
    subgraph "Canary Strategy"
        ALB[Application Load Balancer<br/>Weighted routing]
        
        subgraph "Stable Version"
            StableService[Stable Service v1.0]
            StablePods[Stable Pods v1.0<br/>90% traffic]
        end
        
        subgraph "Canary Version"
            CanaryService[Canary Service v1.1]
            CanaryPods[Canary Pods v1.1<br/>10% traffic]
        end
        
        subgraph "Monitoring"
            Metrics[Success Rate<br/>Latency<br/>Error Rate]
            AutoRollback[Auto Rollback<br/>if metrics fail]
        end
    end
    
    ALB --> StableService
    ALB --> CanaryService
    StableService --> StablePods
    CanaryService --> CanaryPods
    
    StablePods --> Metrics
    CanaryPods --> Metrics
    Metrics --> AutoRollback
    
    classDef stable fill:#2E8B57,stroke:#fff,stroke-width:2px,color:#fff
    classDef canary fill:#FF9900,stroke:#fff,stroke-width:2px,color:#fff
    classDef monitoring fill:#7B68EE,stroke:#fff,stroke-width:2px,color:#fff
    
    class StableService,StablePods stable
    class CanaryService,CanaryPods canary
    class ALB,Metrics,AutoRollback monitoring
```

## Resource Optimization

| Resource Type | Current | Optimized | Savings |
|---------------|---------|-----------|---------|
| **CPU Requests** | 100m per pod | Right-sized based on metrics | 30% |
| **Memory Requests** | 128Mi per pod | Right-sized based on metrics | 25% |
| **Node Utilization** | 60% average | Karpenter bin-packing 85% | 40% |
| **Storage** | gp2 volumes | gp3 volumes | 20% |
| **Network** | Standard ALB | ALB with compression | 15% |

## Security Compliance

### Pod Security Standards
- **Restricted**: All application pods
- **Baseline**: System pods (monitoring, logging)
- **Privileged**: Infrastructure pods (CSI drivers)

### Network Security
- **Default Deny**: All network policies start with deny-all
- **Least Privilege**: Only required ports and protocols
- **Encryption**: TLS for all inter-service communication
- **Segmentation**: Namespace-based isolation

### RBAC Configuration
```yaml
# Example RBAC for application
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-reader
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
```
