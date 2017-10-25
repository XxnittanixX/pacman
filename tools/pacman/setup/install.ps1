if ($PSVersionTable.PSVersion.Major -lt 5) {
    throw ("An older version of PowerShell is used ($($PSVersionTable.PSVersion.ToString())). At least PowerShell 5 is required to run PACMAN.")
}

$Branch = "master"

[IO.DirectoryInfo] $TargetDirectory = (Get-Location).Path
[IO.DirectoryInfo] $TempDirectory = Join-Path "$env:LOCALAPPDATA" "XyrusWorx\Pacman\Setup\$((get-date).Ticks.ToString("X"))"
[IO.DirectoryInfo] $TargetPacmanDirectory = Join-Path $TargetDirectory.FullName "tools\pacman"

$ZipFile = Join-Path $TempDirectory.FullName "pacman-$Branch.zip"
$ErrorActionPreference = "Stop"

if ($TempDirectory.Exists) { 
    Remove-Item -Force -Path $TempDirectory.FullName -Recurse 
}

try {
    Write-Host "Downloading archive..." -NoNewline
    $null = New-Item $TempDirectory.FullName -Force -ItemType Directory
    $null = Invoke-WebRequest -Uri "https://github.com/xyrus02/pacman/archive/$Branch.zip" -UseBasicParsing -OutFile $ZipFile
    Write-Host "OK" -ForegroundColor Green

    Write-Host "Extracting archive..." -NoNewline
    $null = Expand-Archive -Path $ZipFile -DestinationPath $TempDirectory.FullName
    Write-Host "OK" -ForegroundColor Green

    if ($TargetPacmanDirectory.Exists) { 
        Write-Host "Clearing previous installation..." -NoNewline
        Remove-Item -Force -Path $TargetPacmanDirectory.FullName -Recurse 
        Write-Host "OK" -ForegroundColor Green
    }
    
    Write-Host "Deploying to target..." -NoNewline
    $protectedFiles = @(
        Get-ChildItem -Path $TargetDirectory -Recurse -File | `
        Where-Object { -not $_.DirectoryName -eq $TargetDirectory.FullName }
    )
    
    Get-ChildItem -Path (Join-Path $TempDirectory.FullName "pacman-$Branch") | Copy-Item -Destination $TargetDirectory -Exclude $protectedFiles -Force -Recurse
    Write-Host "OK" -ForegroundColor Green
}
catch {
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Exit
}