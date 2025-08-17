# OfferKiller Development Environment Manager for Windows

param(
    [Parameter(Position=0)]
    [string]$Command = "help",
    
    [Parameter(Position=1)]
    [string]$Service = ""
)

function Show-Help {
    Write-Host "OfferKiller Development Environment Manager" -ForegroundColor Green
    Write-Host ""
    Write-Host "Usage: .\scripts\dev-env.ps1 [COMMAND] [SERVICE]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Cyan
    Write-Host "    status      Show Git and project status"
    Write-Host "    build       Build all services locally"
    Write-Host "    test        Run all tests"
    Write-Host "    lint        Run code linting"
    Write-Host "    format      Format code"
    Write-Host "    clean       Clean build artifacts"
    Write-Host "    deploy      Deploy to Linux VM"
    Write-Host "    docs        Generate documentation"
    Write-Host "    help        Show this help message"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Magenta
    Write-Host "    .\scripts\dev-env.ps1 status"
    Write-Host "    .\scripts\dev-env.ps1 build"
    Write-Host "    .\scripts\dev-env.ps1 test"
    Write-Host "    .\scripts\dev-env.ps1 deploy"
}

function Show-Status {
    Write-Host "🔍 OfferKiller Project Status" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Yellow
    
    # Git status
    Write-Host "📝 Git Status:" -ForegroundColor Cyan
    git status --short
    
    # Branch info
    Write-Host "`n🌿 Current Branch:" -ForegroundColor Cyan
    git branch --show-current
    
    # Recent commits
    Write-Host "`n📋 Recent Commits:" -ForegroundColor Cyan
    git log --oneline -5
    
    # Project structure
    Write-Host "`n📁 Project Structure:" -ForegroundColor Cyan
    Get-ChildItem -Directory | Select-Object Name | Format-Table -HideTableHeaders
}

function Build-Services {
    Write-Host "🔨 Building OfferKiller Services..." -ForegroundColor Green
    
    # Backend build
    Write-Host "`n📝 Building Backend Services..." -ForegroundColor Cyan
    if (Test-Path "backend/pom.xml") {
        Push-Location "backend"
        mvn clean compile
        Pop-Location
    } else {
        Write-Host "⚠️  Backend pom.xml not found, skipping..." -ForegroundColor Yellow
    }
    
    # Frontend build
    Write-Host "`n🌐 Building Frontend..." -ForegroundColor Cyan
    if (Test-Path "frontend/package.json") {
        Push-Location "frontend"
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            npm install
            npm run build
        } else {
            Write-Host "⚠️  npm not found, skipping frontend build..." -ForegroundColor Yellow
        }
        Pop-Location
    } else {
        Write-Host "⚠️  Frontend package.json not found, skipping..." -ForegroundColor Yellow
    }
    
    Write-Host "`n✅ Build completed!" -ForegroundColor Green
}

function Run-Tests {
    Write-Host "🧪 Running Tests..." -ForegroundColor Green
    
    # Backend tests
    Write-Host "`n📝 Running Backend Tests..." -ForegroundColor Cyan
    if (Test-Path "backend/pom.xml") {
        Push-Location "backend"
        mvn test
        Pop-Location
    }
    
    # Frontend tests
    Write-Host "`n🌐 Running Frontend Tests..." -ForegroundColor Cyan
    if (Test-Path "frontend/package.json") {
        Push-Location "frontend"
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            npm test
        }
        Pop-Location
    }
    
    # Python tests (if available locally)
    Write-Host "`n🤖 AI Services Tests (requires Python environment)..." -ForegroundColor Cyan
    if (Test-Path "ai-services/requirements.txt") {
        if (Get-Command python -ErrorAction SilentlyContinue) {
            Push-Location "ai-services"
            python -m pytest --version | Out-Null
            if ($LASTEXITCODE -eq 0) {
                python -m pytest
            } else {
                Write-Host "⚠️  pytest not installed, skipping AI services tests..." -ForegroundColor Yellow
            }
            Pop-Location
        } else {
            Write-Host "⚠️  Python not found, skipping AI services tests..." -ForegroundColor Yellow
        }
    }
    
    Write-Host "`n✅ Tests completed!" -ForegroundColor Green
}

function Run-Linting {
    Write-Host "🔍 Running Code Linting..." -ForegroundColor Green
    
    # Java linting (using Maven checkstyle if available)
    Write-Host "`n📝 Java Code Analysis..." -ForegroundColor Cyan
    if (Test-Path "backend/pom.xml") {
        Push-Location "backend"
        mvn validate
        Pop-Location
    }
    
    # Frontend linting
    Write-Host "`n🌐 Frontend Linting..." -ForegroundColor Cyan
    if (Test-Path "frontend/package.json") {
        Push-Location "frontend"
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            npm run lint
        }
        Pop-Location
    }
    
    Write-Host "`n✅ Linting completed!" -ForegroundColor Green
}

function Format-Code {
    Write-Host "🎨 Formatting Code..." -ForegroundColor Green
    
    # Frontend formatting
    if (Test-Path "frontend/package.json") {
        Push-Location "frontend"
        if (Get-Command npm -ErrorAction SilentlyContinue) {
            npm run format
        }
        Pop-Location
    }
    
    # Python formatting (if available)
    if (Get-Command python -ErrorAction SilentlyContinue) {
        Push-Location "ai-services"
        python -m black --version | Out-Null
        if ($LASTEXITCODE -eq 0) {
            python -m black .
        }
        Pop-Location
    }
    
    Write-Host "`n✅ Code formatting completed!" -ForegroundColor Green
}

function Clean-Artifacts {
    Write-Host "🧹 Cleaning Build Artifacts..." -ForegroundColor Green
    
    # Java clean
    if (Test-Path "backend/pom.xml") {
        Push-Location "backend"
        mvn clean
        Pop-Location
    }
    
    # Frontend clean
    if (Test-Path "frontend/node_modules") {
        Remove-Item -Recurse -Force "frontend/node_modules"
    }
    if (Test-Path "frontend/dist") {
        Remove-Item -Recurse -Force "frontend/dist"
    }
    
    Write-Host "`n✅ Cleanup completed!" -ForegroundColor Green
}

function Deploy-ToLinux {
    Write-Host "🚀 Deploying to Linux VM..." -ForegroundColor Green
    
    # Commit and push changes
    Write-Host "`n📤 Pushing changes to GitHub..." -ForegroundColor Cyan
    git add .
    
    $commitMessage = Read-Host "Enter commit message (or press Enter for default)"
    if ([string]::IsNullOrWhiteSpace($commitMessage)) {
        $commitMessage = "Update from Windows development - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    }
    
    git commit -m $commitMessage
    git push
    
    Write-Host "`n🔔 Code pushed to GitHub!" -ForegroundColor Green
    Write-Host "Now SSH to your Linux VM and run:" -ForegroundColor Yellow
    Write-Host "    cd ~/offerkiller" -ForegroundColor White
    Write-Host "    ./deploy.sh" -ForegroundColor White
}

function Generate-Docs {
    Write-Host "📚 Generating Documentation..." -ForegroundColor Green
    
    # Create docs if they don't exist
    if (!(Test-Path "docs/development")) {
        New-Item -ItemType Directory -Path "docs/development" -Force
    }
    
    Write-Host "✅ Documentation structure ready!" -ForegroundColor Green
    Write-Host "Edit documentation files in the docs/ directory" -ForegroundColor Cyan
}

# Main script logic
switch ($Command.ToLower()) {
    "status" { Show-Status }
    "build" { Build-Services }
    "test" { Run-Tests }
    "lint" { Run-Linting }
    "format" { Format-Code }
    "clean" { Clean-Artifacts }
    "deploy" { Deploy-ToLinux }
    "docs" { Generate-Docs }
    "help" { Show-Help }
    default { 
        Write-Host "❌ Unknown command: $Command" -ForegroundColor Red
        Show-Help 
    }
}
