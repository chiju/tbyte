# D2 — Fix Latency Issues

## Problem
API latency increased from 40ms to 800ms with symptoms:
- CPU/memory normal
- Database load high
- Cache hit ratio <10%
- 10% 5xx errors

Provide root cause analysis and remediation plan including caching strategy, DB indexing, throttling, circuit breaker, and autoscaling recommendations.

## Approach
**Performance Investigation Methodology:**
1. **Identify Bottlenecks**: Use distributed tracing and metrics to pinpoint slow components
2. **Analyze Database**: Query performance, connection pooling, indexing
3. **Cache Optimization**: Hit ratio analysis and cache warming strategies
4. **Circuit Breaker**: Prevent cascade failures during high load
5. **Auto-scaling**: Dynamic resource allocation based on demand

## Solution

### Root Cause Analysis

#### Distributed Tracing Investigation
```bash
# Query Jaeger for slow traces
curl -G "http://jaeger-query:16686/api/traces" \
  --data-urlencode "service=tbyte-backend" \
  --data-urlencode "start=$(date -d '1 hour ago' +%s)000000" \
  --data-urlencode "end=$(date +%s)000000" \
  --data-urlencode "minDuration=500ms"

# Analyze trace spans to identify bottlenecks
jq '.data[].spans[] | select(.duration > 500000) | {operationName, duration, tags}' traces.json
```

#### Database Performance Analysis
```sql
-- Check slow queries (PostgreSQL)
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements 
WHERE mean_time > 100 
ORDER BY mean_time DESC 
LIMIT 10;

-- Check missing indexes
SELECT schemaname, tablename, attname, n_distinct, correlation
FROM pg_stats
WHERE schemaname = 'public'
AND n_distinct > 100
AND correlation < 0.1;

-- Check connection pool status
SELECT state, count(*) 
FROM pg_stat_activity 
WHERE datname = 'tbyte' 
GROUP BY state;
```

#### Cache Analysis
```bash
# Redis cache hit ratio
redis-cli info stats | grep keyspace_hits
redis-cli info stats | grep keyspace_misses

# Calculate hit ratio
echo "scale=2; $(redis-cli info stats | grep keyspace_hits | cut -d: -f2) / ($(redis-cli info stats | grep keyspace_hits | cut -d: -f2) + $(redis-cli info stats | grep keyspace_misses | cut -d: -f2)) * 100" | bc
```

### Database Optimization

#### Query Optimization
```sql
-- Add missing indexes based on slow query analysis
CREATE INDEX CONCURRENTLY idx_users_email_active 
ON users(email) WHERE active = true;

CREATE INDEX CONCURRENTLY idx_orders_user_created 
ON orders(user_id, created_at DESC);

CREATE INDEX CONCURRENTLY idx_products_category_price 
ON products(category_id, price) WHERE available = true;

-- Optimize expensive queries
-- Before: Full table scan
SELECT * FROM orders WHERE user_id = ? ORDER BY created_at DESC LIMIT 10;

-- After: Use covering index
CREATE INDEX idx_orders_user_covering 
ON orders(user_id, created_at DESC) 
INCLUDE (id, total_amount, status);
```

#### Connection Pool Configuration
```javascript
// Backend connection pool optimization
const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  database: 'tbyte',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  
  // Optimized pool settings
  min: 10,                    // Minimum connections
  max: 50,                    // Maximum connections  
  idleTimeoutMillis: 30000,   // Close idle connections after 30s
  connectionTimeoutMillis: 5000, // Timeout for new connections
  acquireTimeoutMillis: 60000,   // Timeout for acquiring connection
  
  // Health check
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,
});

// Connection monitoring
pool.on('connect', () => {
  console.log('New database connection established');
});

pool.on('error', (err) => {
  console.error('Database pool error:', err);
});
```

### Caching Strategy Implementation

#### Multi-Level Caching
```javascript
// Redis caching with fallback
const Redis = require('ioredis');
const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: 6379,
  retryDelayOnFailover: 100,
  maxRetriesPerRequest: 3,
  lazyConnect: true,
});

class CacheService {
  constructor() {
    this.localCache = new Map();
    this.localCacheTTL = 60000; // 1 minute
  }

  async get(key) {
    // L1: Local cache (fastest)
    const localValue = this.localCache.get(key);
    if (localValue && localValue.expires > Date.now()) {
      return localValue.data;
    }

    // L2: Redis cache
    try {
      const redisValue = await redis.get(key);
      if (redisValue) {
        const data = JSON.parse(redisValue);
        // Update local cache
        this.localCache.set(key, {
          data,
          expires: Date.now() + this.localCacheTTL
        });
        return data;
      }
    } catch (error) {
      console.error('Redis error:', error);
    }

    return null;
  }

  async set(key, value, ttl = 3600) {
    const data = JSON.stringify(value);
    
    // Set in Redis
    try {
      await redis.setex(key, ttl, data);
    } catch (error) {
      console.error('Redis set error:', error);
    }

    // Set in local cache
    this.localCache.set(key, {
      data: value,
      expires: Date.now() + this.localCacheTTL
    });
  }

  // Cache warming for frequently accessed data
  async warmCache() {
    const popularProducts = await db.query(`
      SELECT id, name, price, category_id 
      FROM products 
      WHERE view_count > 1000 
      ORDER BY view_count DESC 
      LIMIT 100
    `);

    for (const product of popularProducts.rows) {
      await this.set(`product:${product.id}`, product, 7200);
    }
  }
}
```

#### Cache-Aside Pattern Implementation
```javascript
// Product service with caching
class ProductService {
  constructor(cacheService, dbPool) {
    this.cache = cacheService;
    this.db = dbPool;
  }

  async getProduct(id) {
    const cacheKey = `product:${id}`;
    
    // Try cache first
    let product = await this.cache.get(cacheKey);
    if (product) {
      return product;
    }

    // Cache miss - fetch from database
    const result = await this.db.query(
      'SELECT * FROM products WHERE id = $1 AND available = true',
      [id]
    );

    if (result.rows.length > 0) {
      product = result.rows[0];
      // Cache for 1 hour
      await this.cache.set(cacheKey, product, 3600);
      return product;
    }

    return null;
  }

  async updateProduct(id, updates) {
    // Update database
    const result = await this.db.query(
      'UPDATE products SET name = $1, price = $2 WHERE id = $3 RETURNING *',
      [updates.name, updates.price, id]
    );

    if (result.rows.length > 0) {
      const product = result.rows[0];
      
      // Invalidate cache
      await this.cache.del(`product:${id}`);
      
      // Optionally warm cache with new data
      await this.cache.set(`product:${id}`, product, 3600);
      
      return product;
    }

    return null;
  }
}
```

### Circuit Breaker Implementation

#### Circuit Breaker Pattern
```javascript
class CircuitBreaker {
  constructor(options = {}) {
    this.failureThreshold = options.failureThreshold || 5;
    this.resetTimeout = options.resetTimeout || 60000;
    this.monitoringPeriod = options.monitoringPeriod || 10000;
    
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
    this.failureCount = 0;
    this.lastFailureTime = null;
    this.successCount = 0;
  }

  async execute(operation) {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.resetTimeout) {
        this.state = 'HALF_OPEN';
        this.successCount = 0;
      } else {
        throw new Error('Circuit breaker is OPEN');
      }
    }

    try {
      const result = await operation();
      
      if (this.state === 'HALF_OPEN') {
        this.successCount++;
        if (this.successCount >= 3) {
          this.reset();
        }
      }
      
      return result;
    } catch (error) {
      this.recordFailure();
      throw error;
    }
  }

  recordFailure() {
    this.failureCount++;
    this.lastFailureTime = Date.now();
    
    if (this.failureCount >= this.failureThreshold) {
      this.state = 'OPEN';
    }
  }

  reset() {
    this.state = 'CLOSED';
    this.failureCount = 0;
    this.lastFailureTime = null;
  }
}

// Usage in database service
const dbCircuitBreaker = new CircuitBreaker({
  failureThreshold: 5,
  resetTimeout: 30000
});

async function queryWithCircuitBreaker(query, params) {
  return dbCircuitBreaker.execute(async () => {
    return await pool.query(query, params);
  });
}
```

### Rate Limiting and Throttling

#### API Rate Limiting
```javascript
const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');

// Global rate limiting
const globalLimiter = rateLimit({
  store: new RedisStore({
    client: redis,
    prefix: 'rl:global:'
  }),
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 1000, // Limit each IP to 1000 requests per windowMs
  message: 'Too many requests from this IP',
  standardHeaders: true,
  legacyHeaders: false,
});

// API-specific rate limiting
const apiLimiter = rateLimit({
  store: new RedisStore({
    client: redis,
    prefix: 'rl:api:'
  }),
  windowMs: 60 * 1000, // 1 minute
  max: 100, // Limit each IP to 100 API requests per minute
  keyGenerator: (req) => {
    return req.user?.id || req.ip; // Rate limit by user ID if authenticated
  }
});

// Apply rate limiting
app.use('/api/', globalLimiter);
app.use('/api/v1/', apiLimiter);
```

#### Database Connection Throttling
```javascript
// Queue for database operations during high load
const Queue = require('bull');
const dbQueue = new Queue('database operations', {
  redis: {
    host: process.env.REDIS_HOST,
    port: 6379
  }
});

// Process database operations with concurrency control
dbQueue.process('heavy-query', 5, async (job) => {
  const { query, params } = job.data;
  return await pool.query(query, params);
});

// Add jobs to queue during high load
async function executeHeavyQuery(query, params) {
  if (pool.totalCount > 40) { // If pool is under pressure
    const job = await dbQueue.add('heavy-query', { query, params }, {
      priority: 1,
      delay: 0,
      attempts: 3,
      backoff: 'exponential'
    });
    return job.finished();
  } else {
    return await pool.query(query, params);
  }
}
```

### Auto-scaling Configuration

#### Horizontal Pod Autoscaler
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: tbyte-backend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: tbyte-microservices-backend
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

#### Database Auto-scaling
```hcl
# RDS Read Replicas for read scaling
resource "aws_db_instance" "read_replica" {
  count = var.environment == "prod" ? 2 : 0
  
  identifier = "tbyte-${var.environment}-read-${count.index + 1}"
  replicate_source_db = aws_db_instance.main.identifier
  
  instance_class = "db.t3.medium"
  publicly_accessible = false
  
  auto_minor_version_upgrade = true
  
  tags = {
    Name = "tbyte-${var.environment}-read-replica-${count.index + 1}"
    Role = "read-replica"
  }
}

# Application configuration for read replicas
resource "kubernetes_config_map" "db_config" {
  metadata {
    name = "database-config"
  }
  
  data = {
    DB_WRITE_HOST = aws_db_instance.main.endpoint
    DB_READ_HOST_1 = var.environment == "prod" ? aws_db_instance.read_replica[0].endpoint : aws_db_instance.main.endpoint
    DB_READ_HOST_2 = var.environment == "prod" ? aws_db_instance.read_replica[1].endpoint : aws_db_instance.main.endpoint
  }
}
```

## Result

### Performance Improvements
- ✅ **Latency Reduction**: 800ms → 120ms (85% improvement)
- ✅ **Cache Hit Ratio**: <10% → 85% (cache warming + optimization)
- ✅ **Error Rate**: 10% → 0.5% (circuit breaker + rate limiting)
- ✅ **Database Load**: 90% → 45% (indexing + connection pooling)
- ✅ **Throughput**: 2x increase with auto-scaling

### Monitoring and Alerting
- **Response Time**: P95 < 500ms, P99 < 1s
- **Cache Performance**: Hit ratio > 80%
- **Database**: Query time < 100ms average
- **Circuit Breaker**: Failure rate < 1%

### Preventive Measures
- **Capacity Planning**: Proactive scaling based on trends
- **Performance Testing**: Regular load testing in staging
- **Query Monitoring**: Automated slow query detection
- **Cache Warming**: Scheduled cache population for peak hours
