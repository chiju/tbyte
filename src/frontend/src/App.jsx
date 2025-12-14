import { useState, useEffect } from 'react'

function App() {
  const [apiHealth, setApiHealth] = useState(null)
  const [users, setUsers] = useState([])
  const [stats, setStats] = useState(null)

  const testAPI = async (endpoint) => {
    try {
      const response = await fetch(`/api${endpoint}`)
      const data = await response.json()
      return data
    } catch (error) {
      return { error: error.message }
    }
  }

  useEffect(() => {
    testAPI('/health').then(setApiHealth)
  }, [])

  const loadUsers = () => testAPI('/users').then(setUsers)
  const loadStats = () => testAPI('/stats').then(setStats)

  return (
    <div style={{ fontFamily: 'Arial, sans-serif', margin: '40px', background: '#f5f5f5', minHeight: '100vh' }}>
      <div style={{ maxWidth: '800px', margin: '0 auto', background: 'white', padding: '30px', borderRadius: '8px', boxShadow: '0 2px 10px rgba(0,0,0,0.1)' }}>
        <h1 style={{ color: '#2c3e50', textAlign: 'center' }}>🚀 TByte Microservices Platform - GitOps Pipeline Test</h1>
        
        <div style={{ padding: '15px', margin: '20px 0', borderRadius: '5px', background: '#d4edda', border: '1px solid #c3e6cb', color: '#155724' }}>
          <strong>✅ Frontend Service:</strong> Running successfully
        </div>
        
        <div style={{ padding: '15px', margin: '20px 0', borderRadius: '5px', background: '#d1ecf1', border: '1px solid #bee5eb', color: '#0c5460' }}>
          <strong>📊 Architecture:</strong> Frontend → Backend → PostgreSQL
        </div>
        
        <h3>API Testing</h3>
        <div style={{ marginBottom: '20px' }}>
          <button onClick={() => testAPI('/health').then(setApiHealth)} style={{ background: '#007bff', color: 'white', padding: '10px 20px', border: 'none', borderRadius: '5px', cursor: 'pointer', margin: '5px' }}>
            Test Backend Health
          </button>
          <button onClick={loadUsers} style={{ background: '#007bff', color: 'white', padding: '10px 20px', border: 'none', borderRadius: '5px', cursor: 'pointer', margin: '5px' }}>
            Get Users
          </button>
          <button onClick={loadStats} style={{ background: '#007bff', color: 'white', padding: '10px 20px', border: 'none', borderRadius: '5px', cursor: 'pointer', margin: '5px' }}>
            Get Stats
          </button>
        </div>
        
        <div style={{ marginTop: '20px', padding: '15px', background: '#f8f9fa', borderRadius: '5px' }}>
          <h4>API Results:</h4>
          {apiHealth && (
            <div>
              <h5>✅ Backend Health:</h5>
              <pre style={{ background: '#e9ecef', padding: '10px', borderRadius: '3px', overflow: 'auto' }}>
                {JSON.stringify(apiHealth, null, 2)}
              </pre>
            </div>
          )}
          {users.length > 0 && (
            <div>
              <h5>👥 Users:</h5>
              <pre style={{ background: '#e9ecef', padding: '10px', borderRadius: '3px', overflow: 'auto' }}>
                {JSON.stringify(users, null, 2)}
              </pre>
            </div>
          )}
          {stats && (
            <div>
              <h5>📈 Stats:</h5>
              <pre style={{ background: '#e9ecef', padding: '10px', borderRadius: '3px', overflow: 'auto' }}>
                {JSON.stringify(stats, null, 2)}
              </pre>
            </div>
          )}
        </div>
        
        <h3>System Information</h3>
        <ul>
          <li><strong>Environment:</strong> Production</li>
          <li><strong>Frontend:</strong> React + Vite</li>
          <li><strong>Backend:</strong> Node.js + Express</li>
          <li><strong>Database:</strong> PostgreSQL</li>
          <li><strong>Container Registry:</strong> Amazon ECR</li>
          <li><strong>Orchestration:</strong> Kubernetes (EKS)</li>
          <li><strong>Load Balancer:</strong> AWS ALB</li>
          <li><strong>Auto-scaling:</strong> HPA + Karpenter</li>
        </ul>
      </div>
    </div>
  )
}

export default App
// GitOps canary test Sun Dec 14 14:22:42 CET 2025
// Test fixed analysis Sun Dec 14 14:34:39 CET 2025
