# Set label Android menjadi "Ngical" dan applicationId
# Jalankan setelah: flutter create . --project-name ngical

$manifest = "android\app\src\main\AndroidManifest.xml"
if (-not (Test-Path $manifest)) {
    Write-Host "Folder android belum ada. Jalankan dulu: flutter create . --project-name ngical"
    exit 1
}

(Get-Content $manifest) -replace 'android:label="[^"]*"', 'android:label="Ngical"' | Set-Content $manifest
Write-Host "android:label diubah menjadi Ngical"

# Support baik build.gradle maupun build.gradle.kts
$gradle = "android\app\build.gradle"
$gradleKts = "android\app\build.gradle.kts"

if (Test-Path $gradle) {
    (Get-Content $gradle) `
        -replace 'namespace\s*=?\s*"[^"]*"', 'namespace = "com.ngical.pos"' `
        -replace 'applicationId\s*"?[^"\s]*"?', 'applicationId "com.ngical.pos"' `
        | Set-Content $gradle
    Write-Host "applicationId diubah menjadi com.ngical.pos (build.gradle)"
}
elseif (Test-Path $gradleKts) {
    (Get-Content $gradleKts) `
        -replace 'namespace\s*=\s*"[^"]*"', 'namespace = "com.ngical.pos"' `
        -replace 'applicationId\s*=\s*"[^"]*"', 'applicationId = "com.ngical.pos"' `
        | Set-Content $gradleKts
    Write-Host "applicationId diubah menjadi com.ngical.pos (build.gradle.kts)"
}

Write-Host "Selesai. Lanjut: dart run flutter_launcher_icons && flutter build apk --release"
