param(
	[Parameter(Mandatory = $false, Position = 0)] [string] $Environment
)

Import-Module "$PSScriptRoot\modules\Configuration.psm1"
$RepositoryRoot = [IO.Path]::GetFullPath("$PSScriptRoot\..\..\")

if ([string]::IsNullOrWhiteSpace($Environment)) {
    $Environment = (New-XmlPropertyContainer "$RepositoryRoot\config.props").getProperty("DefaultEnvironment")
}

."$PSScriptRoot\LaunchShell.ps1" -RepositoryRoot $RepositoryRoot -Environment $Environment -Headless