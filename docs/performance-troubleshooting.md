# Performance Troubleshooting Guide (Section D2)

## Scenario: API Latency Increased (40ms → 800ms)

### Initial Assessment
- **Symptoms**: API response time increased from 40ms to 800ms
- **System Status**: CPU/memory normal
- **Database**: High load observed
- **Cache**: Hit ratio <10% (critical)
- **Errors**: 10% 5xx error rate

### Root Cause Analysis

#### 1. Database Performance Investigation
```bash
# Check database connections
kubectl exec -it postgres-pod -- psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Check slow queries
kubectl exec -it postgres-pod -- psql -U postgres -c "
SELECT query, mean_time, calls, total_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;"

# Check database locks
kubectl exec -it postgres-pod -- psql -U postgres -c "
SELECT blocked_locks.pid AS blocked_pid,
       blocked_activity.usename AS blocked_user,
       blocking_locks.pid AS blocking_pid,
       blocking_activity.usename AS blocking_user,
       blocked_activity.query AS blocked_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;"
```

#### 2. Cache Performance Analysis
```bash
# Check Redis cache hit ratio
kubectl exec -it redis-pod -- redis-cli info stats | grep keyspace

# Check cache memory usage
kubectl exec -it redis-pod -- redis-cli info memory

# Monitor cache operations
kubectl exec -it redis-pod -- redis-cli monitor
```

#### 3. Application Performance Monitoring
```bash
# Check application metrics in Prometheus
curl -G 'http://prometheus:9090/api/v1/query' \
  --data-urlencode 'query=http_request_duration_seconds{quantile="0.95"}'

# Check error rates
curl -G 'http://prometheus:9090/api/v1/query' \
  --data-urlencode 'query=rate(http_requests_total{status=~"5.."}[5m])'

# Check database connection pool
curl -G 'http://prometheus:9090/api/v1/query' \
  --data-urlencode 'query=db_connections_active'
```

### Remediation Plan

#### Phase 1: Immediate Fixes (0-2 hours)

##### 1. Implement Caching Strategy
```javascript
// Application-level caching
const NodeCache = require('node-cache');
const cache = new NodeCache({ stdTTL: 300 }); // 5 minutes

app.get('/api/users/:id', async (req, res) => {
  const userId = req.params.id;
  const cacheKey = `user:${userId}`;
  
  // Check cache first
  let user = cache.get(cacheKey);
  if (user) {
    return res.json(user);
  }
  
  // Fetch from database
  try {
    user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);
    cache.set(cacheKey, user);
    res.json(user);
  } catch (error) {
    res.status(500).json({ error: 'Database error' });
  }
});
```

##### 2. Database Query Optimization
```sql
-- Add missing indexes
CREATE INDEX CONCURRENTLY idx_users_email ON users(email);
CREATE INDEX CONCURRENTLY idx_orders_user_id ON orders(user_id);
CREATE INDEX CONCURRENTLY idx_orders_created_at ON orders(created_at);

-- Optimize slow queries
EXPLAIN ANALYZE SELECT u.*, COUNT(o.id) as order_count 
FROM users u 
LEFT JOIN orders o ON u.id = o.user_id 
WHERE u.created_at > NOW() - INTERVAL '30 days'
GROUP BY u.id;

-- Add composite index for common query patterns
CREATE INDEX CONCURRENTLY idx_orders_user_status_date 
ON orders(user_id, status, created_at);
```

##### 3. Connection Pool Optimization
```javascript
// Optimize database connection pool
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  port: 5432,
  max: 20,                    // Increased from default 10
  idleTimeoutMillis: 30000,   // Close idle connections after 30s
  connectionTimeoutMillis: 2000, // Fail fast on connection issues
  acquireTimeoutMillis: 60000,   // Wait up to 60s for connection
  createTimeoutMillis: 30000,    // 30s to create new connection
  destroyTimeoutMillis: 5000,    // 5s to destroy connection
  reapIntervalMillis: 1000,      // Check for idle connections every 1s
  createRetryIntervalMillis: 200, // Retry connection creation every 200ms
});
```

#### Phase 2: Circuit Breaker Implementation (2-4 hours)

```javascript
const CircuitBreaker = require('opossum');

// Database circuit breaker
const dbOptions = {
  timeout: 3000,        // 3 second timeout
  errorThresholdPercentage: 50, // Open circuit at 50% error rate
  resetTimeout: 30000,  // Try again after 30 seconds
  rollingCountTimeout: 10000,   // 10 second rolling window
  rollingCountBuckets: 10,      // 10 buckets in rolling window
};

const dbBreaker = new CircuitBreaker(callDatabase, dbOptions);

dbBreaker.fallback(() => {
  return { error: 'Database temporarily unavailable', cached: true };
});

dbBreaker.on('open', () => console.log('Database circuit breaker opened'));
dbBreaker.on('halfOpen', () => console.log('Database circuit breaker half-open'));

async function callDatabase(query, params) {
  const client = await pool.connect();
  try {
    const result = await client.query(query, params);
    return result.rows;
  } finally {
    client.release();
  }
}

// Usage in API endpoint
app.get('/api/users/:id', async (req, res) => {
  try {
    const user = await dbBreaker.fire('SELECT * FROM users WHERE id = $1', [req.params.id]);
    res.json(user);
  } catch (error) {
    res.status(503).json({ error: 'Service temporarily unavailable' });
  }
});
```

#### Phase 3: Advanced Caching (4-8 hours)

##### 1. Redis Cluster Setup
```yaml
# Redis cluster configuration
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
spec:
  serviceName: redis-cluster
  replicas: 6
  template:
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        command:
        - redis-server
        - /etc/redis/redis.conf
        - --cluster-enabled
        - "yes"
        - --cluster-config-file
        - nodes.conf
        - --cluster-node-timeout
        - "5000"
        - --appendonly
        - "yes"
        ports:
        - containerPort: 6379
        - containerPort: 16379
        volumeMounts:
        - name: redis-data
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

##### 2. Multi-Level Caching Strategy
```javascript
// L1: In-memory cache (fastest)
const NodeCache = require('node-cache');
const l1Cache = new NodeCache({ stdTTL: 60 }); // 1 minute

// L2: Redis cache (shared across instances)
const redis = require('redis');
const redisClient = redis.createClient({
  host: process.env.REDIS_HOST,
  port: process.env.REDIS_PORT,
  retry_strategy: (options) => {
    if (options.error && options.error.code === 'ECONNREFUSED') {
      return new Error('Redis server connection refused');
    }
    if (options.total_retry_time > 1000 * 60 * 60) {
      return new Error('Redis retry time exhausted');
    }
    if (options.attempt > 10) {
      return undefined;
    }
    return Math.min(options.attempt * 100, 3000);
  }
});

async function getWithCache(key, fetchFunction, ttl = 300) {
  // L1 Cache check
  let data = l1Cache.get(key);
  if (data) {
    return data;
  }
  
  // L2 Cache check
  try {
    const cached = await redisClient.get(key);
    if (cached) {
      data = JSON.parse(cached);
      l1Cache.set(key, data, ttl / 5); // L1 cache for shorter time
      return data;
    }
  } catch (error) {
    console.error('Redis error:', error);
  }
  
  // Fetch from source
  data = await fetchFunction();
  
  // Store in both caches
  l1Cache.set(key, data, ttl / 5);
  try {
    await redisClient.setex(key, ttl, JSON.stringify(data));
  } catch (error) {
    console.error('Redis set error:', error);
  }
  
  return data;
}
```

#### Phase 4: Database Optimization (8-24 hours)

##### 1. Read Replicas
```yaml
# RDS Read Replica (Terraform)
resource "aws_db_instance" "read_replica" {
  identifier             = "${var.db_identifier}-read-replica"
  replicate_source_db    = aws_db_instance.main.id
  instance_class         = "db.t3.medium"
  publicly_accessible    = false
  auto_minor_version_upgrade = false
  
  tags = {
    Name = "Read Replica"
  }
}
```

##### 2. Connection Routing
```javascript
// Database connection routing
const masterPool = new Pool({
  host: process.env.DB_MASTER_HOST,
  // ... master config
});

const replicaPool = new Pool({
  host: process.env.DB_REPLICA_HOST,
  // ... replica config
});

function getDbPool(operation = 'read') {
  return operation === 'write' ? masterPool : replicaPool;
}

// Usage
async function getUser(id) {
  const pool = getDbPool('read');
  const result = await pool.query('SELECT * FROM users WHERE id = $1', [id]);
  return result.rows[0];
}

async function updateUser(id, data) {
  const pool = getDbPool('write');
  const result = await pool.query(
    'UPDATE users SET name = $1, email = $2 WHERE id = $3 RETURNING *',
    [data.name, data.email, id]
  );
  
  // Invalidate cache after write
  cache.del(`user:${id}`);
  
  return result.rows[0];
}
```

#### Phase 5: Auto-scaling Implementation (24+ hours)

##### 1. Horizontal Pod Autoscaler (HPA)
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-deployment
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

##### 2. KEDA Custom Metrics Scaling
```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: api-scaler
spec:
  scaleTargetRef:
    name: api-deployment
  minReplicaCount: 3
  maxReplicaCount: 20
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: http_request_rate
      threshold: '100'
      query: rate(http_requests_total[1m])
  - type: prometheus
    metadata:
      serverAddress: http://prometheus:9090
      metricName: response_time_p95
      threshold: '500'
      query: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) * 1000
```

### Monitoring and Alerting

#### 1. Performance Dashboards
```yaml
# Grafana dashboard configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: performance-dashboard
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "API Performance",
        "panels": [
          {
            "title": "Response Time P95",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) * 1000"
              }
            ]
          },
          {
            "title": "Error Rate",
            "targets": [
              {
                "expr": "rate(http_requests_total{status=~\"5..\"}[5m]) / rate(http_requests_total[5m]) * 100"
              }
            ]
          },
          {
            "title": "Cache Hit Rate",
            "targets": [
              {
                "expr": "rate(cache_hits_total[5m]) / rate(cache_requests_total[5m]) * 100"
              }
            ]
          }
        ]
      }
    }
```

#### 2. Performance Alerts
```yaml
# Prometheus alerting rules
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: performance-alerts
spec:
  groups:
  - name: api.performance
    rules:
    - alert: HighResponseTime
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.5
      for: 2m
      labels:
        severity: warning
      annotations:
        summary: "High API response time"
        description: "95th percentile response time is {{ $value }}s"
    
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
      for: 1m
      labels:
        severity: critical
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ $value | humanizePercentage }}"
    
    - alert: LowCacheHitRate
      expr: rate(cache_hits_total[5m]) / rate(cache_requests_total[5m]) < 0.8
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Low cache hit rate"
        description: "Cache hit rate is {{ $value | humanizePercentage }}"
```

### Load Testing and Validation

#### 1. Performance Testing with k6
```javascript
// k6 load test script
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },  // Ramp up
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 200 },  // Ramp up to 200 users
    { duration: '5m', target: 200 },  // Stay at 200 users
    { duration: '2m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
    http_req_failed: ['rate<0.1'],    // Error rate under 10%
  },
};

export default function() {
  let response = http.get('http://api.example.com/users/123');
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
}
```

#### 2. Chaos Engineering
```yaml
# Chaos Monkey for database failures
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: database-failure
spec:
  action: pod-failure
  mode: one
  duration: "30s"
  selector:
    labelSelectors:
      app: postgres
  scheduler:
    cron: "0 */6 * * *"  # Every 6 hours
```

### Success Metrics

After implementing the remediation plan, monitor these KPIs:

1. **Response Time**: P95 < 100ms (target: 50ms)
2. **Error Rate**: < 1% (target: 0.1%)
3. **Cache Hit Rate**: > 90% (target: 95%)
4. **Database Connection Pool**: < 80% utilization
5. **Throughput**: > 1000 RPS sustained
6. **Availability**: > 99.9% uptime

### Long-term Optimization

1. **Database Sharding**: Implement horizontal database scaling
2. **CDN Integration**: Use CloudFront for static content
3. **Microservices**: Break monolith into smaller services
4. **Event-Driven Architecture**: Implement async processing
5. **Advanced Caching**: Implement cache warming and invalidation strategies
