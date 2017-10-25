function Invoke-Build {
    [CmdLetBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)] $Package,
        [Parameter(Mandatory = $false)] [string] $Target
    )

    begin {
        $buildEngine = $global:System.Environment.BuildEngine
        
        if ([string]::IsNullOrWhiteSpace($buildEngine)) {
            throw("The environment variable ""BuildEngine"" was not set. Please use the file ""config.props"" in the repository root to provide the variable for the loaded environment ""$(env)"".")
        }
        
        $buildEngineLauncher = Join-Path $PSScriptRoot "..\build\$buildEngine.ps1"

        if (-not (Test-Path $buildEngineLauncher -PathType Leaf)) {
            throw("An unknown or invalid build engine was selected: $buildEngine")
        }        
    }

    process {
        if ($Package -eq $null) {
            Return
        }

        if (-not [string]::Equals($Package.GetType().BaseType.Name, "HierarchyLevel")) {
            Write-Error "Can't build ""$Package"": not a valid package reference"
            Return
        }

        $refs = $Package.getPackages()
        $scriptShell = New-Shell

        try {
            foreach($ref in $refs) {
                $build = $ref.EffectiveConfiguration.getObject().Build
    
                if ($build -eq $null) {
                    continue
                }
    
                if ($build.BeforeBuild -ne $null) {
                    Invoke-Isolated -Context $ref -Command $build.BeforeBuild -Shell $scriptShell -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue")
                }
    
                $projectFilters = "$($build.Projects)".Split(@(";"), [StringSplitOptions]::RemoveEmptyEntries)
                $effectiveTarget = $build.Target
    
                if (-not [string]::IsNullOrWhiteSpace($Target)) {
                    $effectiveTarget = $Target
                }
    
                if ([string]::IsNullOrWhiteSpace($effectiveTarget)) {
                    $effectiveTarget = "Build"
                }
    
                $visited = New-Object "System.Collections.Generic.HashSet[System.String]"
    
                foreach($projectFilter in $projectFilters) {
                
                    $searchPath = Split-Path $projectFilter
    
                    if (-not [IO.Path]::IsPathRooted($searchPath)) {
                        $searchPath = Join-Path ($ref.Directory.FullName) $searchPath
                    }
    
                    $fileFilter = Split-Path -Leaf $projectFilter
                    $projectFiles = @($projectFilters | Foreach-Object { Get-ChildItem -path $searchPath -Filter $fileFilter -File })
    
                    foreach($projectFile in $projectFiles) {
                    
                        if (-not $visited.Add($projectFile.FullName)) {
                            continue
                        }
    
                        if ($pscmdlet.ShouldProcess("$($ref.Class)/$ref", "Build:$effectiveTarget")) {
                            &"$buildEngineLauncher" -Package $ref -Project $projectFile -Target $effectiveTarget
                        }
                    }
                }
            
                if ($build.AfterBuild -ne $null) {
                    Invoke-Isolated -Context $ref -Shell $scriptShell -Command $build.AfterBuild -InformationAction "$InformationPreference" -Verbose:($VerbosePreference -ne "SilentlyContinue")
                }
            }
        }
        finally {
            $scriptShell.Close()
        }
    }
}

Set-Alias "build" "Invoke-Build"
Export-ModuleMember -Function @("Invoke-Build") -Alias @("build")