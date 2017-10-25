param(
	[Parameter(Mandatory = $true, Position = 0)] [string] $RepositoryRoot,
	[Parameter(Mandatory = $false)] [string] $Environment,
	[Parameter(Mandatory = $false)] [switch] $Headless
)

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
		IsHeadlessShell = $Headless
		Environment = @{}
	}
	
	foreach($class in $classes) 
	{
		$success = $success -and ($global:System.Modules.load($class.BaseName))
	}
	
	Write-Host ""

	$ErrorActionPreference = $PreviousErrorActionPreference
	$PreviousErrorActionPreference = $null
	
	Set-Environment -TargetEnvironment $Environment | Out-Null

	if ($success) {
		foreach($include in $includes) 
		{
			."$include"
		}
	}
} 

function prompt {
    $pl = (([IO.DirectoryInfo](Get-Location).Path).FullName).TrimEnd("\")
    $pb = (([IO.DirectoryInfo]$global:System.RootDirectory).FullName).TrimEnd("\")
    
    if ($pl.StartsWith($pb)) {
        $pl = $pl.Substring($pb.Length).TrimStart("\")
    }

    Write-Host ("$pl `$".Trim()) -nonewline -foregroundcolor White
    return " "
}

if (-not $global:System.IsHeadlessShell) {
	write-host -ForegroundColor cyan -NoNewline "PACMAN"
	write-host -ForegroundColor white " Developer Shell"
	write-host -ForegroundColor white "Copyright (c) XyrusWorx. All rights reserved."
	
	write-host -ForegroundColor Gray "`n$(Get-Content -Raw (Join-Path $PSScriptRoot 'welcome.txt'))"
}

Set-Alias -Name reboot -Value Initialize-Shell
Initialize-Shell