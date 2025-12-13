# TByte Architecture Diagrams

## High-Level AWS Architecture

```mermaid
graph TB
    subgraph "Internet"
        User[👤 User]
        GitHub[🐙 GitHub Actions]
    end
    
    subgraph "AWS Account"
        subgraph "VPC (10.0.0.0/16)"
            subgraph "Public Subnets"
                ALB[🔄 Application Load Balancer]
                NAT[🌐 NAT Gateway]
            end
            
            subgraph "Private Subnets"
                subgraph "EKS Cluster"
                    subgraph "Nodes"
                        Frontend[⚛️ Frontend Pods]
                        Backend[🔧 Backend Pods]
                        Postgres[🗄️ PostgreSQL Pods]
                        ArgoCD[🔄 ArgoCD]
                        Monitoring[📊 Prometheus/Grafana]
                    end
                end
                
                RDS[(🗄️ RDS PostgreSQL)]
            end
        end
        
        ECR[📦 ECR Registry]
        S3[🪣 S3 Terraform State]
        CloudWatch[📈 CloudWatch]
        SecretsManager[🔐 Secrets Manager]
    end
    
    User --> ALB
    ALB --> Frontend
    Frontend --> Backend
    Backend --> RDS
    Backend --> Postgres
    
    GitHub --> ECR
    GitHub --> S3
    ArgoCD --> GitHub
    
    Monitoring --> CloudWatch
    Backend --> SecretsManager
    
    style Frontend fill:#e1f5fe
    style Backend fill:#f3e5f5
    style Postgres fill:#e8f5e8
    style RDS fill:#fff3e0
    style ArgoCD fill:#fce4ec
```

## GitOps Workflow

```mermaid
graph LR
    Dev[👨‍💻 Developer] --> Git[📝 Git Push]
    Git --> GHA[🔄 GitHub Actions]
    
    subgraph "CI/CD Pipeline"
        GHA --> Build[🔨 Build Images]
        Build --> Test[🧪 Run Tests]
        Test --> Push[📦 Push to ECR]
        Push --> Deploy[🚀 Deploy Infrastructure]
        Deploy --> Update[📝 Update App Configs]
    end
    
    Update --> ArgoCD[🔄 ArgoCD]
    
    subgraph "EKS Cluster"
        ArgoCD --> Sync[🔄 Auto Sync]
        Sync --> Apps[📱 Applications]
        Apps --> Monitor[📊 Monitor Health]
    end
    
    Monitor --> Alert[🚨 Alerts]
    Alert --> Dev
    
    style GHA fill:#f0f8ff
    style ArgoCD fill:#fce4ec
    style Apps fill:#e8f5e8
```

## Kubernetes Application Architecture

```mermaid
graph TB
    subgraph "Ingress Layer"
        ALB[AWS ALB]
        Istio[Istio Gateway]
    end
    
    subgraph "Application Layer"
        subgraph "Frontend Namespace"
            FE1[Frontend Pod 1]
            FE2[Frontend Pod 2]
            FESvc[Frontend Service]
        end
        
        subgraph "Backend Namespace"
            BE1[Backend Pod 1]
            BE2[Backend Pod 2]
            BESvc[Backend Service]
        end
        
        subgraph "Database Namespace"
            PG1[PostgreSQL Pod]
            PGSvc[PostgreSQL Service]
            PVC[Persistent Volume]
        end
    end
    
    subgraph "Infrastructure Layer"
        subgraph "Monitoring"
            Prometheus[Prometheus]
            Grafana[Grafana]
            Loki[Loki]
        end
        
        subgraph "Scaling"
            KEDA[KEDA Controller]
            Karpenter[Karpenter]
        end
        
        subgraph "Security"
            ESO[External Secrets]
            Vault[HashiCorp Vault]
        end
    end
    
    ALB --> Istio
    Istio --> FESvc
    FESvc --> FE1
    FESvc --> FE2
    
    FE1 --> BESvc
    FE2 --> BESvc
    BESvc --> BE1
    BESvc --> BE2
    
    BE1 --> PGSvc
    BE2 --> PGSvc
    PGSvc --> PG1
    PG1 --> PVC
    
    KEDA --> FE1
    KEDA --> BE1
    Karpenter --> FE1
    
    ESO --> BE1
    ESO --> Vault
    
    Prometheus --> FE1
    Prometheus --> BE1
    Grafana --> Prometheus
    
    style FE1 fill:#e1f5fe
    style BE1 fill:#f3e5f5
    style PG1 fill:#e8f5e8
```

## Security Architecture

```mermaid
graph TB
    subgraph "External"
        GitHub[GitHub Actions]
        User[End User]
    end
    
    subgraph "AWS Security"
        OIDC[OIDC Provider]
        IAM[IAM Roles]
        SM[Secrets Manager]
        KMS[AWS KMS]
    end
    
    subgraph "Network Security"
        SG[Security Groups]
        NACL[Network ACLs]
        NP[Network Policies]
    end
    
    subgraph "Kubernetes Security"
        RBAC[RBAC Rules]
        SA[Service Accounts]
        PSP[Pod Security]
        ESO[External Secrets]
    end
    
    subgraph "Application Security"
        TLS[TLS Encryption]
        Auth[Authentication]
        Secrets[Secret Management]
    end
    
    GitHub --> OIDC
    OIDC --> IAM
    IAM --> SA
    
    User --> SG
    SG --> NACL
    NACL --> NP
    
    SA --> RBAC
    RBAC --> PSP
    
    ESO --> SM
    SM --> KMS
    
    PSP --> TLS
    TLS --> Auth
    Auth --> Secrets
    
    style OIDC fill:#fff3e0
    style RBAC fill:#e8f5e8
    style TLS fill:#fce4ec
```

## Monitoring & Observability

```mermaid
graph TB
    subgraph "Data Sources"
        Apps[Applications]
        K8s[Kubernetes API]
        AWS[AWS Services]
        Logs[Application Logs]
    end
    
    subgraph "Collection Layer"
        Prometheus[Prometheus]
        Promtail[Promtail]
        EventExporter[Event Exporter]
        CWAgent[CloudWatch Agent]
    end
    
    subgraph "Storage Layer"
        PromDB[(Prometheus DB)]
        Loki[(Loki)]
        CloudWatch[(CloudWatch)]
    end
    
    subgraph "Visualization"
        Grafana[Grafana Dashboards]
        AlertManager[Alert Manager]
        Slack[Slack Notifications]
    end
    
    Apps --> Prometheus
    K8s --> Prometheus
    K8s --> EventExporter
    Logs --> Promtail
    AWS --> CWAgent
    
    Prometheus --> PromDB
    Promtail --> Loki
    EventExporter --> Loki
    CWAgent --> CloudWatch
    
    PromDB --> Grafana
    Loki --> Grafana
    CloudWatch --> Grafana
    
    PromDB --> AlertManager
    AlertManager --> Slack
    
    style Prometheus fill:#ff6b6b
    style Grafana fill:#4ecdc4
    style Loki fill:#45b7d1
```

## How to Use These Diagrams

1. **Copy the Mermaid code** from any diagram above
2. **Paste into online tools**:
   - [Mermaid Live Editor](https://mermaid.live/)
   - [Draw.io](https://app.diagrams.net/) (supports Mermaid import)
   - VS Code with Mermaid extension
3. **Export as PNG/SVG** for your presentation
4. **Include in documentation** or PowerPoint slides

## Architecture Highlights

- **High Availability**: Multi-AZ deployment with auto-scaling
- **Security**: Zero-trust model with encryption everywhere
- **Observability**: 360° monitoring with metrics, logs, and events
- **Automation**: GitOps workflow with infrastructure as code
- **Cost Optimization**: Right-sizing with Karpenter and resource limits
