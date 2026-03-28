# DadyTube - Fast Offline Build Script
# This script builds the APK without checking for updates or downloading dependencies.

Write-Host "Starting Fast Offline Build for DadyTube..." -ForegroundColor Cyan

$FLUTTER_PATH = "C:\flutter2\bin\flutter.bat"
$PROJECT_ROOT = Get-Location

# 1. Update local package resolution without internet
Write-Host "Resolving dependencies offline..." -ForegroundColor Yellow
& $FLUTTER_PATH pub get --offline

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to resolve dependencies offline. You may need to run 'flutter pub get' with internet first if you added new packages."
    exit $LASTEXITCODE
}

# 2. Build Release APK skipping network checks
# --no-pub: Skips the implicit pub get check which often hangs on slow connections
Write-Host "Building APK..." -ForegroundColor Yellow
& $FLUTTER_PATH build apk --release --no-pub

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build Successful!" -ForegroundColor Green
    Write-Host "Location: $PROJECT_ROOT\build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor White
} else {
    Write-Error "Build failed. Check the error log above."
    exit $LASTEXITCODE
}
