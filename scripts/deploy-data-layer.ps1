# OfferKiller Data Layer Deployment Script
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("development", "staging", "production")]
    [string]$Environment = "development",
    
    [Parameter(Mandatory=$false)]
    [string]$KubeConfig = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipRedis = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipRabbitMQ = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipVectorDB = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

Write-Host "🚀 OfferKiller Data Layer Deployment ($Environment)" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green

# Set kubeconfig if provided
if ($KubeConfig -ne "") {
    $env:KUBECONFIG = $KubeConfig
    Write-Host "📁 Using kubeconfig: $KubeConfig" -ForegroundColor Yellow
}

# Function to check prerequisites
function Test-Prerequisites {
    Write-Host "🔍 Checking prerequisites..." -ForegroundColor Cyan
    
    # Check kubectl
    try {
        kubectl version --client --short | Out-Null
        Write-Host "✅ kubectl is available" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ kubectl is not available" -ForegroundColor Red
        return $false
    }
    
    # Check helm
    try {
        helm version --short | Out-Null
        Write-Host "✅ Helm is available" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Helm is not available" -ForegroundColor Red
        return $false
    }
    
    # Check cluster connectivity
    try {
        kubectl cluster-info | Out-Null
        Write-Host "✅ Cluster is accessible" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Cannot connect to cluster" -ForegroundColor Red
        return $false
    }
    
    # Check required namespaces
    $namespaces = @("offerkiller-data", "offerkiller-system")
    foreach ($ns in $namespaces) {
        $exists = kubectl get namespace $ns --ignore-not-found=true 2>$null
        if (-not $exists) {
            Write-Host "📦 Creating namespace: $ns" -ForegroundColor Yellow
            if (-not $DryRun) {
                kubectl create namespace $ns
            }
        }
    }
    
    return $true
}

# Function to deploy Helm chart
function Deploy-HelmChart {
    param(
        [string]$ChartPath,
        [string]$ReleaseName,
        [string]$Namespace,
        [string]$ValuesFile,
        [string]$Description
    )
    
    Write-Host "📦 Deploying $Description..." -ForegroundColor Cyan
    
    $helmCmd = "helm upgrade --install $ReleaseName $ChartPath -n $Namespace --create-namespace"
    
    if ($ValuesFile -and (Test-Path $ValuesFile)) {
        $helmCmd += " -f $ValuesFile"
    }
    
    if ($DryRun) {
        $helmCmd += " --dry-run"
    } else {
        $helmCmd += " --wait --timeout 10m"
    }
    
    if ($Force) {
        $helmCmd += " --force"
    }
    
    Write-Host "🔧 Command: $helmCmd" -ForegroundColor Gray
    
    try {
        Invoke-Expression $helmCmd
        Write-Host "✅ $Description deployed successfully" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Failed to deploy $Description" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

# Function to wait for deployment
function Wait-ForDeployment {
    param(
        [string]$Namespace,
        [string]$DeploymentName,
        [int]$TimeoutSeconds = 300
    )
    
    if ($DryRun) {
        Write-Host "🏃 Skipping wait in dry run mode" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "⏳ Waiting for $DeploymentName to be ready..." -ForegroundColor Yellow
    
    $timeout = [datetime]::Now.AddSeconds($TimeoutSeconds)
    while ([datetime]::Now -lt $timeout) {
        try {
            $ready = kubectl get statefulset $DeploymentName -n $Namespace -o jsonpath='{.status.readyReplicas}' 2>$null
            $desired = kubectl get statefulset $DeploymentName -n $Namespace -o jsonpath='{.spec.replicas}' 2>$null
            
            if ($ready -eq $desired -and $ready -gt 0) {
                Write-Host "✅ $DeploymentName is ready!" -ForegroundColor Green
                return $true
            }
        }
        catch {
            # Deployment might not exist yet
        }
        
        Start-Sleep -Seconds 10
    }
    
    Write-Host "⚠️ Timeout waiting for $DeploymentName" -ForegroundColor Yellow
    return $false
}

# Function to verify services
function Test-Services {
    Write-Host "🔍 Verifying services..." -ForegroundColor Cyan
    
    if (-not $SkipRedis) {
        Write-Host "Testing Redis cluster..." -ForegroundColor Yellow
        $redisTest = kubectl exec -n offerkiller-data redis-cluster-0 -- redis-cli ping 2>$null
        if ($redisTest -eq "PONG") {
            Write-Host "✅ Redis cluster is responding" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Redis cluster is not responding" -ForegroundColor Yellow
        }
    }
    
    if (-not $SkipRabbitMQ) {
        Write-Host "Testing RabbitMQ cluster..." -ForegroundColor Yellow
        $rmqTest = kubectl exec -n offerkiller-data rabbitmq-ha-0 -- rabbitmqctl cluster_status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ RabbitMQ cluster is operational" -ForegroundColor Green
        } else {
            Write-Host "⚠️ RabbitMQ cluster has issues" -ForegroundColor Yellow
        }
    }
    
    if (-not $SkipVectorDB) {
        Write-Host "Testing Vector Database..." -ForegroundColor Yellow
        $vectorTest = kubectl exec -n offerkiller-data vector-database-0 -- curl -s http://localhost:8000/api/v1/heartbeat 2>$null
        if ($vectorTest) {
            Write-Host "✅ Vector Database is responding" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Vector Database is not responding" -ForegroundColor Yellow
        }
    }
}

# Main deployment logic
if (-not (Test-Prerequisites)) {
    exit 1
}

# Navigate to project root
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "📂 Working directory: $PWD" -ForegroundColor Yellow
Write-Host "🎯 Target environment: $Environment" -ForegroundColor Yellow

# Deploy Redis Cluster
if (-not $SkipRedis) {
    $valuesFile = "infrastructure/helm/values/$Environment/redis-cluster.yaml"
    $success = Deploy-HelmChart -ChartPath "infrastructure/helm/charts/redis-cluster" `
                               -ReleaseName "redis-cluster" `
                               -Namespace "offerkiller-data" `
                               -ValuesFile $valuesFile `
                               -Description "Redis Cluster"
    
    if ($success) {
        Wait-ForDeployment -Namespace "offerkiller-data" -DeploymentName "redis-cluster"
    } else {
        Write-Host "❌ Redis deployment failed" -ForegroundColor Red
        exit 1
    }
}

# Deploy RabbitMQ Cluster
if (-not $SkipRabbitMQ) {
    $valuesFile = "infrastructure/helm/values/$Environment/rabbitmq-ha.yaml"
    $success = Deploy-HelmChart -ChartPath "infrastructure/helm/charts/rabbitmq-ha" `
                               -ReleaseName "rabbitmq-ha" `
                               -Namespace "offerkiller-data" `
                               -ValuesFile $valuesFile `
                               -Description "RabbitMQ HA Cluster"
    
    if ($success) {
        Wait-ForDeployment -Namespace "offerkiller-data" -DeploymentName "rabbitmq-ha"
    } else {
        Write-Host "❌ RabbitMQ deployment failed" -ForegroundColor Red
        exit 1
    }
}

# Deploy Vector Database
if (-not $SkipVectorDB) {
    $valuesFile = "infrastructure/helm/values/$Environment/vector-database.yaml"
    $success = Deploy-HelmChart -ChartPath "infrastructure/helm/charts/vector-database" `
                               -ReleaseName "vector-database" `
                               -Namespace "offerkiller-data" `
                               -ValuesFile $valuesFile `
                               -Description "Vector Database"
    
    if ($success) {
        Wait-ForDeployment -Namespace "offerkiller-data" -DeploymentName "vector-database"
    } else {
        Write-Host "❌ Vector Database deployment failed" -ForegroundColor Red
        exit 1
    }
}

# Verify deployments
Write-Host "`n🔍 Deployment Status:" -ForegroundColor Yellow
kubectl get pods -n offerkiller-data
kubectl get svc -n offerkiller-data
kubectl get pvc -n offerkiller-data

# Test services
Test-Services

Write-Host "`n🎉 Data layer deployment completed!" -ForegroundColor Green

# Get access information
if (-not $DryRun) {
    $minikubeIP = try { minikube ip } catch { "localhost" }
    
    Write-Host "`n📝 Access Information:" -ForegroundColor Yellow
    Write-Host "   Redis Cluster:     $minikubeIP:30379" -ForegroundColor Cyan
    Write-Host "   RabbitMQ Mgmt:     http://$minikubeIP:31672 (offerkilleruser/rabbitmq123change)" -ForegroundColor Cyan
    Write-Host "   Vector Database:   http://$minikubeIP:30800" -ForegroundColor Cyan
    
    Write-Host "`n🔧 Useful Commands:" -ForegroundColor Yellow
    Write-Host "   kubectl get pods -n offerkiller-data" -ForegroundColor White
    Write-Host "   kubectl logs -f statefulset/redis-cluster -n offerkiller-data" -ForegroundColor White
    Write-Host "   kubectl logs -f statefulset/rabbitmq-ha -n offerkiller-data" -ForegroundColor White
    Write-Host "   kubectl logs -f deployment/vector-database -n offerkiller-data" -ForegroundColor White
}

Write-Host "`n🚀 Ready for application deployment!" -ForegroundColor Green
