# OfferKiller Development Access Setup Script
Write-Host "🔗 Setting up development access to data layer services..." -ForegroundColor Green

# Function to start port forward in background
function Start-PortForward {
    param(
        [string]$Service,
        [string]$Namespace,
        [string]$LocalPort,
        [string]$RemotePort,
        [string]$Description
    )
    
    Write-Host "🚀 Starting port forward for $Description..." -ForegroundColor Cyan
    Write-Host "   Local: localhost:$LocalPort -> Remote: $Service:$RemotePort" -ForegroundColor Yellow
    
    $job = Start-Job -ScriptBlock {
        param($Service, $Namespace, $LocalPort, $RemotePort)
        kubectl port-forward -n $Namespace "svc/$Service" "${LocalPort}:${RemotePort}"
    } -ArgumentList $Service, $Namespace, $LocalPort, $RemotePort
    
    return $job
}

# Start port forwards
$jobs = @()

# Redis Cluster
$jobs += Start-PortForward -Service "redis-cluster" -Namespace "offerkiller-data" -LocalPort "6379" -RemotePort "6379" -Description "Redis Cluster"

# RabbitMQ Management
$jobs += Start-PortForward -Service "rabbitmq-ha" -Namespace "offerkiller-data" -LocalPort "15672" -RemotePort "15672" -Description "RabbitMQ Management UI"

# RabbitMQ AMQP
$jobs += Start-PortForward -Service "rabbitmq-ha" -Namespace "offerkiller-data" -LocalPort "5672" -RemotePort "5672" -Description "RabbitMQ AMQP"

# Vector Database
$jobs += Start-PortForward -Service "vector-database" -Namespace "offerkiller-data" -LocalPort "8000" -RemotePort "8000" -Description "Vector Database API"

Write-Host "`n✅ Port forwards started!" -ForegroundColor Green
Write-Host "`n📝 Access Information:" -ForegroundColor Yellow
Write-Host "   Redis:             localhost:6379" -ForegroundColor Cyan
Write-Host "   RabbitMQ AMQP:     localhost:5672" -ForegroundColor Cyan
Write-Host "   RabbitMQ Mgmt:     http://localhost:15672 (offerkilleruser/rabbitmq123change)" -ForegroundColor Cyan
Write-Host "   Vector Database:   http://localhost:8000" -ForegroundColor Cyan

Write-Host "`n🔧 Test Commands:" -ForegroundColor Yellow
Write-Host "   Redis:     redis-cli -h localhost -p 6379 ping" -ForegroundColor White
Write-Host "   RabbitMQ:  Open http://localhost:15672 in browser" -ForegroundColor White
Write-Host "   Vector:    curl http://localhost:8000/api/v1/heartbeat" -ForegroundColor White

Write-Host "`n⚠️  Press Ctrl+C to stop all port forwards" -ForegroundColor Yellow

# Wait for user input to stop
try {
    while ($true) {
        Start-Sleep -Seconds 5
        
        # Check if any jobs failed
        $failedJobs = $jobs | Where-Object { $_.State -eq "Failed" }
        if ($failedJobs) {
            Write-Host "⚠️ Some port forwards failed. Restarting..." -ForegroundColor Yellow
            $failedJobs | ForEach-Object { Remove-Job $_ -Force }
            # Restart logic could be added here
        }
    }
}
finally {
    Write-Host "`n🛑 Stopping all port forwards..." -ForegroundColor Yellow
    $jobs | ForEach-Object { Stop-Job $_ -Force; Remove-Job $_ -Force }
    Write-Host "✅ All port forwards stopped." -ForegroundColor Green
}
