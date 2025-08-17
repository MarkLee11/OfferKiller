@echo off
:: OfferKiller Quick Deploy Script for Windows

echo.
echo 🚀 OfferKiller Quick Deploy
echo ===============================

:: Check if we're in the right directory
if not exist ".git" (
    echo ❌ Error: Not in a Git repository directory
    echo Please run this script from the OfferKiller project root
    pause
    exit /b 1
)

:: Show current status
echo.
echo 📋 Current Git Status:
git status --short

:: Ask for commit message
echo.
set /p "commit_msg=Enter commit message (or press Enter for auto-generated): "

:: Generate default commit message if empty
if "%commit_msg%"=="" (
    for /f "tokens=2 delims= " %%i in ('date /t') do set current_date=%%i
    for /f "tokens=1 delims= " %%i in ('time /t') do set current_time=%%i
    set "commit_msg=Development update - %current_date% %current_time%"
)

:: Add all changes
echo.
echo 📦 Adding all changes...
git add .

:: Commit changes
echo.
echo 💾 Committing changes...
git commit -m "%commit_msg%"

:: Push to GitHub
echo.
echo 📤 Pushing to GitHub...
git push

:: Success message
echo.
echo ✅ Code successfully pushed to GitHub!
echo.
echo 🔧 Next steps:
echo 1. SSH to your Linux VM
echo 2. Navigate to ~/offerkiller
echo 3. Run: ./deploy.sh
echo.
echo 🌐 Or connect via SSH and auto-deploy:
echo ssh your-vm-user@your-vm-ip "cd ~/offerkiller && ./deploy.sh"
echo.

pause
