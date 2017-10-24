function Expand-TemplatePackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] [string] $TemplateFile,
        [Parameter(Mandatory = $true, Position = 0)] [string] $Destination,
        [Parameter(Mandatory = $false)] $Context,
        [switch] $Force
    )

    $TempPath = Join-Path $env:TEMP "~Template$($Destination.GetHashCode())"

    if (Test-Path -Path $TempPath -PathType Container) {
        Remove-Item -Path $TempPath -Recurse -Force
    }

    $null = New-Item -Path $TempPath -ItemType Directory

    Copy-Item -Path $TemplateFile -Destination "$TempPath.zip"
    Expand-Archive -Path "$TempPath.zip" -DestinationPath $TempPath
    Remove-Item -Force -Path "$TempPath.zip"
    
    foreach($item in @(Get-ChildItem -Path $TempPath -Recurse -Filter "*.pp" -File)) {
        
        [IO.File]::WriteAllText(
            (Join-Path $item.DirectoryName $item.BaseName), 
            (Get-Content -Raw -Path $item.FullName | Expand-Template -Context $Context -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue")))

        Remove-Item -Path $item.FullName -Force
    }

    if (-not (Test-Path -Path $Destination -PathType Container)) {
        $null = New-Item -Path $Destination -ItemType Directory
    }

    if (-not $Force) {
        $preExistingFiles = @(Get-ChildItem -Path $Destination -Recurse -File | Where-Object { $_.FullName -ne (Join-Path $_.DirectoryName "package.props") })
    }
    else {
        $preExistingFiles = @()
    }

    Get-ChildItem -Path $TempPath | Copy-Item -Destination $Destination -Exclude $preExistingFiles
    Remove-Item -Path $TempPath -Recurse -Force
}

function Expand-Template {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] [string] $Template,
        [Parameter(Mandatory = $false)] $Context
    )

    $beginTag = [regex]::Escape("[[")
    $endTag = [regex]::Escape("]]")

    $shell = New-Shell
    $inputString = $Template
    $outputStringBuilder = New-Object "System.Text.StringBuilder"

    try {
        while ($inputString -match "(?s)(?<pre>.*?)$beginTag(?<exp>.*?)$endTag(?<post>.*)") {
            $inputString = $matches.post
            $null = $outputStringBuilder.Append($matches.pre)
            $null = $outputStringBuilder.Append((Invoke-Isolated -Shell $shell -Command $matches.exp -Context $Context -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue") | Out-String).TrimEnd())
        }
        
        $null = $outputStringBuilder.Append($inputString)
        return $outputStringBuilder.ToString()
    }
    finally {
        $shell.Close()
    }
}

Export-ModuleMember `
    -Function @(
        "Expand-Template",
        "Expand-TemplatePackage"
    ) `
    -Alias @(
    )