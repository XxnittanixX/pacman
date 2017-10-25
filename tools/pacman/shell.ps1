param(
	[Parameter(Mandatory = $true, Position = 0)] [string] $RepositoryRoot,
	[Parameter(Mandatory = $false)] [string] $DefaultRepository,
	[Parameter(Mandatory = $false)] [string] $Environment,
	[Parameter(Mandatory = $false)] [switch] $Headless
)

function Get-ShellParameters {
	return `
		"-RepositoryRoot ""$RepositoryRoot""" + `
		"-DefaultRepository ""$DefaultRepository""" + `
		"-Environment ""$Environment"""
}

class ModuleContainer {

	hidden [System.Collections.Generic.HashSet[System.String]] $_Modules
	
	ModuleContainer() {
		$this._Modules = New-Object System.Collections.Generic.HashSet[System.String]
	}

	[bool] load($Name) {
	
		if ([string]::IsNullOrWhiteSpace($Name)) {
			return $false
		}
		
		$fullPath = Join-Path $PSScriptRoot "modules\$Name.psm1"
		Write-Host -NoNewLine "Loading module ""$Name""..."
		
		try {
			$ErrorActionPreference = "Stop"
		
			if (-not (Test-Path -PathType Leaf -Path $fullPath)) {
				throw "The module is not installed."
			}
			
			Import-Module "$fullPath"
		} 
		catch {
			Write-Host -ForegroundColor Red "FAILED: $($_.Exception.Message)"
			return $false
		}
		
		Write-Host -ForegroundColor Green "OK"
		$null = $this._Modules.Add($Name.ToLower())
		
		return $true
	}
	[bool] isLoaded($Name) {
		if ([string]::IsNullOrWhiteSpace($Name)) {
			return $false
		}
	
		return $this._Modules.Contains($Name.ToLower())
	}
}

function Set-Environment {
	param([Parameter(ValueFromPipeline = $true, Position = 0)] [string] $TargetEnvironment)

	$config = (New-XmlPropertyContainer (Join-Path $RepositoryRoot "config.props")).getObject()

	if ([string]::IsNullOrWhiteSpace($TargetEnvironment)) {
		return $global:Environment
	}
	
	$env = $config.$TargetEnvironment
	
	if ($env -eq $null) {
		$env = @{}
	}
	
	$global:System.Environment = $env
	$global:Environment = $TargetEnvironment
	
	return $TargetEnvironment
}

function Initialize-Shell { 
	Remove-Variable * -ErrorAction SilentlyContinue
	Remove-Module *

	$error.Clear()

	$PreviousErrorActionPreference = $ErrorActionPreference
	write-host ""
	
	$classes = Get-ChildItem -filter "*.psm1" -path "$PSScriptRoot\modules"
	$includes = Get-ChildItem -filter "*.ps1" -path "$PSScriptRoot\include"
	$success = $true
	
	$global:System = @{
		Modules = (New-Object ModuleContainer)
		RootDirectory = $RepositoryRoot
		DefaultRepository = $DefaultRepository
		Environment = @{}
	}
	
	if ([string]::IsNullOrWhiteSpace($DefaultRepository)) { 
		$global:System.DefaultRepository = "src"
	}
	
	$global:Repository = $null
	
	foreach($class in $classes) 
	{
		$success = $success -and ($global:System.Modules.load($class.BaseName))
	}
	
	$ErrorActionPreference = $PreviousErrorActionPreference
	$PreviousErrorActionPreference = $null
	
	write-host ""
	
	if (-not $success -and -not $Headless) {
		$host.ui.RawUI.WindowTitle = "PACMAN - <unknown repository>"
		exit
	}
	
	$global:Repository = Get-PackageRepository
	$displayTitle = $global:Repository.EffectiveConfiguration.getProperty("Title")
	
	if ([string]::IsNullOrWhiteSpace($displayTitle)) {
		$displayTitle = $global:Repository.Name
	}
	if ([string]::IsNullOrWhiteSpace($displayTitle)) {
		$displayTitle = "<unknown repository>"
	}
	
	if (-not $Headless) {
		Invoke-Expression -Command "`$host.ui.RawUI.WindowTitle = 'PACMAN - $displayTitle'" -ErrorAction SilentlyContinue
	}
	
	foreach($include in $includes) 
	{
		."$include"
	}
	
	Set-Environment -TargetEnvironment $Environment | Out-Null
} 

function prompt {
    $pl = (Get-Location).Path
    $pb = "$($global:System.RootDirectory)".TrimEnd("\")
    
    if ($pl.StartsWith($pb)) {
        $pl = $pl.Substring($pb.Length).TrimStart("\")
    }

    Write-Host ("$pl `$".Trim()) -nonewline -foregroundcolor White
    return " "
}

write-host -ForegroundColor cyan -NoNewline "PACMAN"
write-host -ForegroundColor white " Developer Shell"
write-host -ForegroundColor white "Copyright (c) XyrusWorx. All rights reserved."

write-host -ForegroundColor Gray "`n$(Get-Content -Raw (Join-Path $PSScriptRoot 'welcome.txt'))"

Set-Alias -Name reboot -Value Initialize-Shell
Set-Alias -Name env -Value Set-Environment
Initialize-Shell