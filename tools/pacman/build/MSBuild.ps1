param(
    [Parameter(Mandatory = $true)] $Package,
    [Parameter(Mandatory = $true)] $Project,
    [Parameter(Mandatory = $true)] $Target
)

$buildTools = $global:System.Environment.BuildToolsPath

if ([string]::IsNullOrWhiteSpace($buildTools)) {
    throw("The environment variable ""BuildToolsPath"" was not set. Please use the file ""config.props"" in the repository root to provide the variable for the loaded environment ""$(env)"".")
}

if (-not (Test-Path (Join-Path $buildTools "msbuild.exe") -PathType Leaf)) {
    throw("MSBuild was not found at the provided build tools path: $($buildTools)")
}

$elr = [regex]::new("^(?:.*?)(?:\(\d+,\d+\))?:\s+error\s+(?:[A-Z]+\d+)?:\s(.*?)$", "IgnoreCase")
$wlr = [regex]::new("^(?:.*?)(?:\(\d+,\d+\))?:\s+warning\s+(?:[A-Z]+\d+)?:\s(.*?)$", "IgnoreCase")

[IO.FileInfo] $projectFile = $Project

Write-Information "Starting MSBuild on project file: $($projectFile.FullName)"
$msbuildCommand = "/v:minimal /nologo /consoleloggerparameters:""NoSummary;ForceNoAlign"" /t:""$Target"" "

$Package.EffectiveConfiguration.getProperties("BuildProperties") | Foreach-Object {
    $msbuildCommand = "$msbuildCommand/p:$_=""$($Package.EffectiveConfiguration.getProperty("BuildProperties", $_))"" "
}

$msbuildCommand = "$msbuildCommand""$($projectFile.FullName)"""
Write-Verbose "MSBuild command line: $msbuildCommand"

$errorCount = 0
"&""$(Join-Path $buildTools "msbuild.exe")"" $msbuildCommand" | Invoke-Expression | Foreach-Object {

    $elm = $elr.Match($_)
    $wlm = $wlr.Match($_)

    if ($elm.Success) {
        $errorCount ++
        Write-Error -Message $elm.Groups[1].Value -Category FromStdErr
    }
    elseif ($wlm.Success) {
        Write-Warning -Message $wlm.Groups[1].Value
    }
    else {
        Write-Information $_.TrimStart()
    }
}

if (($errorCount -le 0) -and ($LASTEXITCODE -ne 0)) {
    throw("Failed to build project: $($projectFile.FullName)")
}