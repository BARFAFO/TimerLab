param(
    # Use this when calling the script from an already-open PowerShell terminal.
    # By default the script pauses at the end so Explorer-launched windows stay visible.
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$exitWithError = $false

try {
    $project = Join-Path $PSScriptRoot "src\TimerLab\TimerLab.csproj"
    $distDir = Join-Path $PSScriptRoot "dist"
    $publishDir = Join-Path $distDir "publish"
    $exe = Join-Path $publishDir "TimerLab.exe"
    $buildInfoPath = Join-Path $publishDir ".timerlab-build.json"

    if (-not (Test-Path -LiteralPath $project -PathType Leaf)) {
        throw "TimerLab project file was not found: $project. Extract the complete source ZIP and run this script from the TimerLab folder."
    }
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw "Published TimerLab.exe was not found: $exe. Run .\build.ps1 first."
    }

    # Read the project version without depending on Select-Xml output formatting.
    [xml]$projectXml = Get-Content -LiteralPath $project -Raw
    $versionNode = $projectXml.SelectSingleNode('/Project/PropertyGroup/Version')
    $version = if ($null -ne $versionNode) { $versionNode.InnerText.Trim() } else { $null }
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "Could not read the Version property from $project."
    }

    if (-not (Test-Path -LiteralPath $buildInfoPath -PathType Leaf)) {
        throw "Build metadata is missing: $buildInfoPath. This executable may come from the previous 1.0.0 build. Run .\build.ps1 from this same TimerLab folder WITHOUT -FrameworkDependent, then run .\package-release.ps1 again."
    }

    try {
        $buildInfo = Get-Content -LiteralPath $buildInfoPath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Build metadata is unreadable or invalid: $buildInfoPath. Run .\build.ps1 again. Details: $($_.Exception.Message)"
    }

    if ($buildInfo.Version -ne $version -or
        $buildInfo.RuntimeIdentifier -ne "win-x64" -or
        $buildInfo.BuildConfiguration -ne "Release") {
        throw "The executable's build metadata does not match project version $version / win-x64 / Release. Run .\build.ps1 again before packaging."
    }
    if ($buildInfo.SelfContained -ne $true) {
        throw "The published executable is framework-dependent. Friends would need the .NET 10 Desktop Runtime. Run .\build.ps1 WITHOUT -FrameworkDependent, then package again."
    }

    $releaseZip = Join-Path $distDir "TimerLab_v${version}_win-x64.zip"
    $stagingZip = Join-Path $distDir "TimerLab_v${version}_win-x64.tmp.zip"
    $backupZip = Join-Path $distDir "TimerLab_v${version}_win-x64.previous.zip"
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null

    if (Test-Path -LiteralPath $stagingZip) {
        Remove-Item -LiteralPath $stagingZip -Force
    }

    $exeSizeMB = [math]::Round((Get-Item -LiteralPath $exe).Length / 1MB, 2)
    Write-Host "Creating the shareable TimerLab release ZIP..." -ForegroundColor Cyan
    Write-Host "Source executable: $exe" -ForegroundColor DarkGray
    Compress-Archive -LiteralPath $exe -DestinationPath $stagingZip -CompressionLevel Optimal -ErrorAction Stop

    if (-not (Test-Path -LiteralPath $stagingZip -PathType Leaf)) {
        throw "ZIP creation failed; no release archive was produced."
    }

    # Verify that the archive contains exactly one file, TimerLab.exe.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipCheck = [System.IO.Compression.ZipFile]::OpenRead($stagingZip)
    try {
        if ($zipCheck.Entries.Count -ne 1 -or $zipCheck.Entries[0].Name -ne "TimerLab.exe") {
            throw "The generated ZIP does not contain exactly one TimerLab.exe file. The release archive was not installed."
        }
    }
    finally {
        $zipCheck.Dispose()
    }

    # Install the new archive only after creation and content validation succeed.
    if (Test-Path -LiteralPath $backupZip) {
        Remove-Item -LiteralPath $backupZip -Force
    }
    $hadPreviousZip = Test-Path -LiteralPath $releaseZip
    if ($hadPreviousZip) {
        Move-Item -LiteralPath $releaseZip -Destination $backupZip -ErrorAction Stop
    }
    try {
        Move-Item -LiteralPath $stagingZip -Destination $releaseZip -ErrorAction Stop
    }
    catch {
        if (Test-Path -LiteralPath $releaseZip) {
            Remove-Item -LiteralPath $releaseZip -Force -ErrorAction SilentlyContinue
        }
        if ($hadPreviousZip -and (Test-Path -LiteralPath $backupZip)) {
            Move-Item -LiteralPath $backupZip -Destination $releaseZip -ErrorAction SilentlyContinue
        }
        throw "Could not install the new release ZIP. The previous ZIP was restored when possible. Details: $($_.Exception.Message)"
    }
    if (Test-Path -LiteralPath $backupZip) {
        Remove-Item -LiteralPath $backupZip -Force
    }

    $zipSizeMB = [math]::Round((Get-Item -LiteralPath $releaseZip).Length / 1MB, 2)
    Write-Host "" 
    Write-Host "PACKAGE CREATED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "Executable: $exe ($exeSizeMB MB)" -ForegroundColor Cyan
    Write-Host "Shareable ZIP: $releaseZip ($zipSizeMB MB)" -ForegroundColor Green
    Write-Host "ZIP contents verified: TimerLab.exe only." -ForegroundColor Green
    Write-Host "The local executable remains in dist\publish. Send the ZIP from dist to your friends." -ForegroundColor Green
}
catch {
    $exitWithError = $true
    Write-Host ""
    Write-Host "TIMERLAB PACKAGING FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host "" 
        Write-Host "Diagnostic location:" -ForegroundColor Yellow
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkYellow
    }
}

if (-not $NoPause) {
    try { [void](Read-Host "Press Enter to close this window") } catch { }
}

if ($exitWithError) {
    throw "Packaging did not complete. Review the error above."
}
