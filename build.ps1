param(
    # Publish a tiny framework-dependent exe instead of the self-contained one.
    # It needs the .NET 10 Desktop Runtime (x64) on whichever machine runs it.
    [switch]$FrameworkDependent
)

$ErrorActionPreference = "Stop"
$projectDir = Join-Path $PSScriptRoot "src\TimerLab"
$project = Join-Path $projectDir "TimerLab.csproj"
$distDir = Join-Path $PSScriptRoot "dist"
$stagingDir = Join-Path $distDir ".publish-staging"
$publishDir = Join-Path $distDir "publish"

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw ".NET SDK was not found. Install the .NET 10 SDK, then run build.ps1 again."
}
$installedSdks = @(& dotnet --list-sdks 2>&1)
if ($LASTEXITCODE -ne 0) {
    throw "Could not query installed .NET SDKs. Run 'dotnet --list-sdks' in a terminal to diagnose the .NET installation."
}
if (-not ($installedSdks | Where-Object { $_ -match '^\s*10\.' })) {
    $found = if ($installedSdks.Count -gt 0) { $installedSdks -join ", " } else { "none" }
    throw ".NET 10 SDK is required to build TimerLab (target: net10.0-windows). Installed SDKs: $found. Install the .NET 10 SDK from https://dotnet.microsoft.com/download/dotnet/10.0, then reopen PowerShell and run build.ps1 again."
}
if (-not (Test-Path -LiteralPath $project -PathType Leaf)) {
    throw "TimerLab project file was not found: $project"
}
if (Get-Process -Name "TimerLab" -ErrorAction SilentlyContinue) {
    throw "Close TimerLab before rebuilding so the previous executable can be replaced safely."
}

# The version lives only in the .csproj; the scripts read it from there.
$version = (Select-Xml -LiteralPath $project -XPath "/Project/PropertyGroup/Version").Node.InnerText
if ([string]::IsNullOrWhiteSpace($version)) {
    throw "Could not read <Version> from $project."
}
$releaseZip = Join-Path $distDir "TimerLab_v${version}_win-x64.zip"
$backupDir = Join-Path $distDir ".publish-backup"

New-Item -ItemType Directory -Path $distDir -Force | Out-Null
if (Test-Path -LiteralPath $stagingDir) {
    Remove-Item -LiteralPath $stagingDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

# Single-file, compression and the other size settings come from the .csproj.
$publishArgs = @($project, "--configuration", "Release", "--runtime", "win-x64", "--output", $stagingDir)
if ($FrameworkDependent) {
    $publishArgs += @("--self-contained", "false")
    Write-Host "Building TimerLab v$version (Release, win-x64, framework-dependent single-file; needs the .NET 10 Desktop Runtime)..." -ForegroundColor Cyan
}
else {
    $publishArgs += @("--self-contained", "true")
    Write-Host "Building TimerLab v$version (Release, win-x64, self-contained, compressed single-file)..." -ForegroundColor Cyan
}
& dotnet publish @publishArgs

if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE. Existing dist output and source files were not intentionally removed."
}

$stagingExe = Join-Path $stagingDir "TimerLab.exe"
if (-not (Test-Path -LiteralPath $stagingExe -PathType Leaf)) {
    throw "Publish completed but the expected executable was not found: $stagingExe"
}

# PDB files are development-only debug symbols and are not needed to run TimerLab.
Get-ChildItem -LiteralPath $stagingDir -Filter "*.pdb" -File -ErrorAction SilentlyContinue |
    Remove-Item -Force

# Record the publish mode so the packaging script can verify that a shareable
# release is self-contained instead of guessing from the executable's file size.
$buildInfo = [ordered]@{
    Version = $version
    RuntimeIdentifier = "win-x64"
    SelfContained = [bool](-not $FrameworkDependent)
    BuildConfiguration = "Release"
}
$buildInfoPath = Join-Path $stagingDir ".timerlab-build.json"
$buildInfo | ConvertTo-Json | Set-Content -LiteralPath $buildInfoPath -Encoding UTF8

# Swap the completed publish into place. Keep the previous usable build until
# the new directory has been moved successfully; restore it if the swap fails.
if (Test-Path -LiteralPath $backupDir) {
    Remove-Item -LiteralPath $backupDir -Recurse -Force
}
$hadPreviousPublish = Test-Path -LiteralPath $publishDir
if ($hadPreviousPublish) {
    Move-Item -LiteralPath $publishDir -Destination $backupDir
}
try {
    Move-Item -LiteralPath $stagingDir -Destination $publishDir
}
catch {
    if (Test-Path -LiteralPath $publishDir) {
        Remove-Item -LiteralPath $publishDir -Recurse -Force
    }
    if ($hadPreviousPublish -and (Test-Path -LiteralPath $backupDir)) {
        Move-Item -LiteralPath $backupDir -Destination $publishDir
    }
    throw "Could not install the new publish directory. The previous build was restored when possible. Details: $_"
}
if (Test-Path -LiteralPath $backupDir) {
    Remove-Item -LiteralPath $backupDir -Recurse -Force
}

# Do not keep a second on-disk copy of the executable by default.
# A release ZIP can be generated separately with package-release.ps1 when needed.
if (Test-Path -LiteralPath $releaseZip) {
    Remove-Item -LiteralPath $releaseZip -Force
    Write-Host "Removed previous distribution ZIP to avoid storing the executable twice." -ForegroundColor DarkGray
}

# Remove only generated compiler output. These folders are recreated by the next build.
# Source files, assets, project settings, and the published executable are retained.
$generatedDirs = @(
    (Join-Path $projectDir "bin"),
    (Join-Path $projectDir "obj")
)
foreach ($generatedDir in $generatedDirs) {
    if (Test-Path -LiteralPath $generatedDir) {
        $generatedBytes = (Get-ChildItem -LiteralPath $generatedDir -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        if ($null -eq $generatedBytes) { $generatedBytes = 0 }
        Remove-Item -LiteralPath $generatedDir -Recurse -Force
        $removedMB = [math]::Round($generatedBytes / 1MB, 1)
        Write-Host "Removed generated build folder: $generatedDir ($removedMB MB)" -ForegroundColor DarkGray
    }
}

$exe = Join-Path $publishDir "TimerLab.exe"
$exeSizeMB = [math]::Round((Get-Item -LiteralPath $exe).Length / 1MB, 2)
Write-Host "Executable: $exe ($exeSizeMB MB)" -ForegroundColor Green

# Keep the shortcut pointed at the stable dist path, not a temporary build directory.
$desktop = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
if (-not [string]::IsNullOrWhiteSpace($desktop)) {
    try {
        $shortcutPath = Join-Path $desktop "TimerLab.lnk"
        $wsh = New-Object -ComObject WScript.Shell
        $shortcut = $wsh.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exe
        $shortcut.WorkingDirectory = $publishDir
        $shortcut.Description = "TimerLab v$version - Windows timer resolution control and measurement"
        $shortcut.IconLocation = "$exe,0"
        $shortcut.Save()
        Write-Host "Desktop shortcut created: $shortcutPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "The app was published and the source build folders were cleaned, but the Desktop shortcut could not be created: $_"
    }
}
else {
    Write-Warning "Windows did not return a Desktop directory. The published executable remains at: $exe"
}

Write-Host "Build complete. The self-contained executable is ready for local use." -ForegroundColor Green
Write-Host "To create a shareable ZIP later, run: .\package-release.ps1" -ForegroundColor Cyan
Start-Process -FilePath $exe -WorkingDirectory $publishDir
Write-Host "TimerLab v$version launched." -ForegroundColor Green
