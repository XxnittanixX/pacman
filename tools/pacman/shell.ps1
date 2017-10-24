param(
	[Parameter(Mandatory = $true, Position = 0)] [string] $RepositoryRoot,
	[Parameter(Mandatory = $false)] [string] $DefaultRepository,
	[Parameter(Mandatory = $false)] [string] $Environment
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
		Write-Host -NoNewLine "Loading $Name..."
		
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

$global:System = @{}
$global:Repository = @{}

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

function Get-Repository { return $global:Repository }
function Load-Shell { 
	$PreviousErrorActionPreference = $ErrorActionPreference
	write-host ""
	
	$classes = gci -filter "*.psm1" -path "$PSScriptRoot\modules"
	$includes = gci -filter "*.ps1" -path "$PSScriptRoot\include"
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
	
	if (-not $success) {
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
	
	$host.ui.RawUI.WindowTitle = "PACMAN - $displayTitle"
	
	foreach($include in $includes) 
	{
		."$include"
	}
	
	Set-Environment -TargetEnvironment $Environment | Out-Null
} 

set-alias -Name reboot -Value Load-Shell
set-alias -Name repo -Value Get-Repository
set-alias -Name env -Value Set-Environment

function prompt
{
    $pl = (gl).Path
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

write-host -ForegroundColor Gray @"

Permission is hereby granted, free of charge, to any person obtaining a copy 
of this software and associated documentation files (the "Software"), to deal 
in the Software without restriction, including without limitation the rights 
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
copies of the Software, and to permit persons to whom the Software is fur-
nished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIA-
BILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
THE SOFTWARE.
"@

Load-Shell