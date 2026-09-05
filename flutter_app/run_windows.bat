@echo off
echo Cleaning up old build files...
rmdir /s /q build 2>nul
rmdir /s /q .dart_tool 2>nul

echo Setting up virtual M: drive to bypass Windows path limits...
subst M: /D >nul 2>&1
subst M: "%~dp0\.."

echo Launching Matka Management...
cd /d M:\flutter_app
flutter run -d windows
