# Set nama binary Windows menjadi Ngical.exe + fix MSVC 14.51 coroutine error
# Jalankan setelah: flutter create . --project-name ngical

$cmake = "windows\CMakeLists.txt"
if (-not (Test-Path $cmake)) {
    Write-Host "Folder windows belum ada. Jalankan dulu: flutter create . --project-name ngical"
    exit 1
}

# 1. Ubah BINARY_NAME menjadi Ngical
$content = Get-Content $cmake -Raw
$content = $content -replace 'set\(BINARY_NAME ".*"\)', 'set(BINARY_NAME "Ngical")'

# 2. Tambahkan define untuk suppress error STL1011 (experimental coroutine)
#    Ini wajib untuk Visual Studio 18 / MSVC 14.51+
$silenceLine = 'add_compile_definitions(_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)'
if ($content -notmatch [regex]::Escape($silenceLine)) {
    # Sisipkan setelah baris project(...)
    if ($content -match '(project\s*\([^\)]*\))') {
        $content = $content -replace '(project\s*\([^\)]*\))', "`$1`r`n`r`n# Fix MSVC 14.51+ experimental coroutine deprecation (STL1011)`r`n$silenceLine"
        Write-Host "Ditambahkan: _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"
    } else {
        # Fallback: taruh di paling atas setelah cmake_minimum_required
        $content = $content -replace '(cmake_minimum_required\s*\([^\)]*\))', "`$1`r`n`r`n$silenceLine"
        Write-Host "Ditambahkan (fallback): _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"
    }
} else {
    Write-Host "Define silence sudah ada, dilewati."
}

Set-Content $cmake -Value $content -NoNewline
Write-Host "BINARY_NAME diubah menjadi Ngical"

# 3. Update product name di Runner.rc jika ada
$rc = "windows\runner\Runner.rc"
if (Test-Path $rc) {
    (Get-Content $rc) `
        -replace 'VALUE "FileDescription", ".*"', 'VALUE "FileDescription", "Ngical"' `
        -replace 'VALUE "ProductName", ".*"', 'VALUE "ProductName", "Ngical"' `
        -replace 'VALUE "InternalName", ".*"', 'VALUE "InternalName", "Ngical"' `
        -replace 'VALUE "OriginalFilename", ".*"', 'VALUE "OriginalFilename", "Ngical.exe"' `
        | Set-Content $rc
    Write-Host "Runner.rc diupdate (ProductName, FileDescription, dll)"
}

# 4. Pastikan icon Windows memakai app_icon.ico (jika runner masih default)
$runnerCmake = "windows\runner\CMakeLists.txt"
if (Test-Path $runnerCmake) {
    $rcContent = Get-Content $runnerCmake -Raw
    if ($rcContent -notmatch 'app_icon\.ico') {
        Write-Host "Catatan: pastikan resources.rc / Runner.rc merujuk ke icon yang benar."
    }
}

Write-Host ""
Write-Host "Selesai. Sekarang jalankan:"
Write-Host "  flutter clean"
Write-Host "  flutter pub get"
Write-Host "  flutter run -d windows"
Write-Host "atau"
Write-Host "  flutter build windows --release"
