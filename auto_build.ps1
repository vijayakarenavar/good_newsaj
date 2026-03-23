# Read pubspec.yaml
$pubspecPath = "pubspec.yaml"
$content = Get-Content $pubspecPath -Raw

# Find version line
if ($content -match "version:\s*(\d+\.\d+\.\d+)\+(\d+)") {
    $versionName = $matches[1]
    $buildNumber = [int]$matches[2]
    $newBuild = $buildNumber + 1
    $newVersion = "$versionName+$newBuild"

    # Replace version
    $newContent = $content -replace "version:\s*\d+\.\d+\.\d+\+\d+", "version: $newVersion"
    Set-Content $pubspecPath $newContent

    Write-Host "Updated Version: $newVersion"

    # Build APK
    Write-Host "Building APK..."
    flutter build apk --release

    # Build AAB
    Write-Host "Building AAB..."
    flutter build appbundle --release

    Write-Host "Done! APK + AAB ready!"
}
else {
    Write-Host "Version not found!"
}