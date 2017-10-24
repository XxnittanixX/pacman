function Expand-TemplatePackage {
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
            (Get-Content -Raw -Path $item.FullName | Expand-Template -Context $Context))

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
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] [string] $Template,
        [Parameter(Mandatory = $false)] $Context
    )

    $beginTag = [regex]::Escape("[[")
    $endTag = [regex]::Escape("]]")

    $isolatedRunspace = [RunspaceFactory]::CreateRunspace()
    $isolatedRunspace.Open()

    $inputString = $Template
    $outputStringBuilder = New-Object System.Text.StringBuilder

    try {

        try {
            [PowerShell] $isolatedShell = [PowerShell]::Create()
            $isolatedShell.Runspace = $isolatedRunspace
            
            $null = $isolatedShell.AddScript("$PSScriptRoot\..\shell.ps1 $(Get-ShellParameters)")
            $null = $isolatedShell.Invoke()
        }
        finally {
            $isolatedShell.Dispose()
        }

        while ($inputString -match "(?s)(?<pre>.*?)$beginTag(?<exp>.*?)$endTag(?<post>.*)") {
            $inputString = $matches.post
            $null = $outputStringBuilder.Append($matches.pre)

            try {
                [PowerShell] $isolatedShell = [PowerShell]::Create()
                $isolatedShell.Runspace = $isolatedRunspace
                $null = $isolatedShell.AddCommand("Foreach-Object").AddParameter("Process", [Scriptblock]::Create($matches.exp))
                $scriptResult = $isolatedShell.Invoke(@($Context))
                $compositeScriptResult = @($scriptResult | ForEach-Object { "$_" }) -join [Environment]::NewLine
                $null = $outputStringBuilder.Append($compositeScriptResult)
            }
            finally {
                $isolatedShell.Dispose()
            }
        }
        
        $null = $outputStringBuilder.Append($inputString)
        return $outputStringBuilder.ToString()
    }
    finally {
        $isolatedRunspace.Close()
    }
}

Export-ModuleMember `
    -Function @(
        "Expand-Template",
        "Expand-TemplatePackage"
    ) `
    -Alias @(
    )