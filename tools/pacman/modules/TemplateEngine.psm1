function Expand-TemplatePackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)] [string] $TemplateFile,
        [Parameter(Mandatory = $true, Position = 0)] [string] $Destination,
        [Parameter(Mandatory = $false)] $Context,
        [switch] $Force
    )

    $ContentPath = Join-Path $env:TEMP "~Template$($Destination.GetHashCode())"
    
    if (Test-Path -Path $ContentPath -PathType Container) {
        Remove-Item -Path $ContentPath -Recurse -Force
    }

    if (Test-Path -Path $TemplateFile -PathType Container) {
        Copy-Item -Path $TemplateFile -Destination $ContentPath -Recurse
    } 
    elseif (Test-Path -Path $TemplateFile -PathType Leaf) {
        $null = New-Item -Path $ContentPath -ItemType Directory
    
        Copy-Item -Path $TemplateFile -Destination "$ContentPath.zip"
        Expand-Archive -Path "$ContentPath.zip" -DestinationPath $ContentPath
        Remove-Item -Force -Path "$ContentPath.zip"
    } 
    else {
        throw("Template file ""$TemplateFile"" not found.")
    }

    [IO.FileInfo] $prepareScript = Join-Path $ContentPath "prepare.ps1"
    [IO.FileInfo] $initScript = Join-Path $ContentPath "init.ps1"
    [IO.FileInfo] $updateScript = Join-Path $ContentPath "update.ps1"

    if ($prepareScript.Exists) {
        Get-Content -Raw -Path $prepareScript.FullName | Invoke-Isolated -Context $Context -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue")
    }
    
    foreach($item in @(Get-ChildItem -Path $ContentPath -Recurse -Filter "*.pp" -File)) {
        
        [IO.File]::WriteAllText(
            (Join-Path $item.DirectoryName $item.BaseName), 
            (Get-Content -Raw -Path $item.FullName | Expand-Template -Context $Context -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue")))

        Remove-Item -Path $item.FullName -Force
    }

    if (-not (Test-Path -Path $Destination -PathType Container)) {
        $null = New-Item -Path $Destination -ItemType Directory
    }

    if (-not $Force) {
        $preExistingFiles = @(Get-ChildItem -Path $Destination -Recurse -File | Where-Object { $_.FullName -ne (Join-Path $_.DirectoryName "package.json") })
    }
    else {
        $preExistingFiles = @()
    }

    Get-ChildItem -Path $ContentPath | Copy-Item -Recurse -Destination $Destination -Exclude $preExistingFiles

    if ($initScript.Exists) {
        if ($preExistingFiles.Count -eq 0) {
            Get-Content -Raw -Path $initScript.FullName | Invoke-Isolated -Context $Context -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue")
        }
        Remove-Item -Force -Path (Join-Path $Destination $initScript.Name)
    }
    
    if ($updateScript.Exists) {
        if ($preExistingFiles.Count -gt 0) {
            Get-Content -Raw -Path $updateScript.FullName | Invoke-Isolated -Context $Context -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue")
        }
        Remove-Item -Force -Path (Join-Path $Destination $updateScript.Name)
    }

    if ($prepareScript.Exists) {
        Remove-Item -Force -Path (Join-Path $Destination $prepareScript.Name)
    }

    Remove-Item -Path $ContentPath -Recurse -Force
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
        $length = $inputString.Length
        while ($inputString -match "(?s)(?<pre>.*?)$beginTag(?<exp>.*?)$endTag(?<post>.*)") {
            $inputString = $matches.post

            if ($inputString.Length -eq $length) {
                Write-Warning "Template processor seems stuck. Is there a nested expression (not supported)? Aborting..."
                break
            }

            $null = $outputStringBuilder.Append($matches.pre)
            $expression = $matches.exp

            Write-Verbose "Processing expression: $expression"
            # TODO GK: Executing isolated commands seems to get stuck when WinRM is disabled. There should
            # be a check whether this is the case and possibly a warning.
            #$result = (Invoke-Isolated -Shell $shell -Command $expression -Context $Context -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue") | Out-String).TrimEnd()
            $result = ($context | Invoke-Command -Command ([ScriptBlock]::Create("Foreach-Object { $expression }")) | Out-String).TrimEnd()
           
            Write-Verbose "Expression processor result: $result"
            $null = $outputStringBuilder.Append($result)
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