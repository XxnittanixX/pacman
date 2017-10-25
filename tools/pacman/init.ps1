Import-Module "$PSScriptRoot\modules\Configuration.psm1"

$RepositoryRoot = [IO.Path]::GetFullPath("$PSScriptRoot\..\..\")
$Environment = (new-xmlpropertycontainer "$RepositoryRoot\config.props").getProperty("DefaultEnvironment")

."$PSScriptRoot\LaunchShell.ps1" -RepositoryRoot $RepositoryRoot -Environment $Environment -Headless