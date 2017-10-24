function New-Shell {
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory = $false)] [switch] $NoRuntime
    )

    $Runspace = [RunspaceFactory]::CreateRunspace()
    $Runspace.Open()
    
    [PowerShell] $isolatedShell = [PowerShell]::Create()
    try {
        
        $isolatedShell.Runspace = $isolatedRunspace

        $null = $isolatedShell.AddScript("$PSScriptRoot\..\shell.ps1 $(Get-ShellParameters)")
        $null = $isolatedShell.Invoke()
        
    }
    finally {
        $isolatedShell.Dispose()
    }

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
            $null = $processor.AddCommand("Foreach-Object").AddParameter("Process", [Scriptblock]::Create($Command))
            return @($processor.Invoke(@($Context)))
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