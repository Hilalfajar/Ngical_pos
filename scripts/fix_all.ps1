# ============================================================
# Ngical - Script perbaikan lengkap (Windows + Android branding)
# Jalankan dari root project:  powershell -ExecutionPolicy Bypass -File scripts\fix_all.ps1
# ============================================================

Write-Host "=== Ngical Fix All ===" -ForegroundColor Cyan
Write-Host ""

# Pastikan di root project
if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "ERROR: Jalankan script ini dari folder root project (yang ada pubspec.yaml)" -ForegroundColor Red
    exit 1
}

# 1. Pastikan platform folders ada
if (-not (Test-Path "windows") -or -not (Test-Path "android")) {
    Write-Host "Folder windows/android belum lengkap. Menjalankan flutter create..." -ForegroundColor Yellow
    flutter create . --project-name ngical --platforms=windows,android
    if ($LASTEXITCODE -ne 0) {
        Write-Host "flutter create gagal. Pastikan Flutter sudah terinstall." -ForegroundColor Red
        exit 1
    }
}

# 2. Windows branding + fix MSVC coroutine
Write-Host ""
Write-Host "--- Fix Windows (BINARY_NAME + silence coroutine) ---" -ForegroundColor Green
& "$PSScriptRoot\set_windows_name.ps1"

# 3. Android label
Write-Host ""
Write-Host "--- Fix Android label ---" -ForegroundColor Green
& "$PSScriptRoot\set_android_label.ps1"

# 4. Generate icons
Write-Host ""
Write-Host "--- Generate launcher icons ---" -ForegroundColor Green
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) {
    Write-Host "Peringatan: flutter_launcher_icons gagal (bisa diabaikan jika icon sudah ada)." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== SELESAI ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Langkah berikutnya:"
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter run -d windows"
Write-Host ""
Write-Host "Atau build release:"
Write-Host "  flutter build windows --release"
Write-Host "  flutter build apk --release"
