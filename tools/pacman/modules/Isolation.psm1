function New-Shell {
    param(
        [switch] $NoRuntime
    )

    $Runspace = [RunspaceFactory]::CreateRunspace()
    $Runspace.Open()
    
    if (-not $NoRuntime) {
        [PowerShell] $isolatedShell = [PowerShell]::Create()
        try {
    
            $isolatedShell.Runspace = $Runspace
            $null = $isolatedShell.AddScript("$PSScriptRoot\..\shell.ps1 -RepositoryRoot '$($global:System.RootDirectory)' -Environment '$($global:Environment)' -Headless") 
            $null = $isolatedShell.Invoke()
            
        }
        finally {
            $isolatedShell.Dispose()
        }
    }

    $Runspace.SessionStateProxy.SetVariable("VerbosePreference", "Continue")
    $Runspace.SessionStateProxy.SetVariable("InformationPreference", "Continue")
    $Runspace.SessionStateProxy.SetVariable("WarningPreference", "Continue")
    $Runspace.SessionStateProxy.SetVariable("ErrorActionPreference", "Stop")

    return $Runspace
}

function Invoke-Isolated {
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)] [string] $Command,
        [Parameter(Mandatory = $false)] [Runspace] $Shell,
        [Parameter(Mandatory = $false)] $Context,
        [Parameter(Mandatory = $false)] [switch] $NoRuntime
    )

    $hasExternalShell = $Shell -ne $null

    if (-not $hasExternalShell) {
        $Shell = New-Shell -NoRuntime:$NoRuntime
    }
    
    try {
        [PowerShell] $processor = [PowerShell]::Create()
        try {
            $processor.Runspace = $Shell
            $null = $processor.AddCommand("Foreach-Object").AddParameter("Process", [Scriptblock]::Create($Command)).AddParameter("Verbose").AddParameter("InformationAction", "Continue")` 
            $Result = @($processor.Invoke(@($Context)))
            
            $processor.Streams.Warning.ReadAll() | ForEach-Object { Write-Warning $_.Message }
            $processor.Streams.Information.ReadAll() | ForEach-Object { Write-Information -MessageData $_.MessageData }
            $processor.Streams.Verbose.ReadAll() | ForEach-Object { Write-Verbose $_.Message }

            return $result
        }
        finally {
            $processor.Dispose()
        }
    }
    finally {
        if (-not $hasExternalShell){
            $Shell.Close()
        }
    }
}

Export-ModuleMember -Function @("New-Shell", "Invoke-Isolated")