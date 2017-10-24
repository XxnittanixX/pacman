function Invoke-Build {
    [CmdLetBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)] $Package,
        [Parameter(Mandatory = $false)] [string] $Target
    )

    begin {
        $buildTools = $global:System.Environment.BuildToolsPath

        if ([string]::IsNullOrWhiteSpace($buildTools)) {
            throw("The environment variable ""BuildToolsPath"" was not set. Please use the file ""config.props"" in the repository root to provide the variable for the loaded environment ""$(env)"".")
        }

        if (-not (Test-Path (Join-Path $buildTools "msbuild.exe") -PathType Leaf)) {
            throw("MSBuild was not found at the provided build tools path: $($buildTools)")
        }

        $elr = [regex]::new("^(?:.*?)(?:\(\d+,\d+\))?:\s+error\s+(?:[A-Z]+\d+)?:\s(.*?)$", "IgnoreCase")
        $wlr = [regex]::new("^(?:.*?)(?:\(\d+,\d+\))?:\s+warning\s+(?:[A-Z]+\d+)?:\s(.*?)$", "IgnoreCase")
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
                    $projectFiles = @($projectFilters|%{gci -path $searchPath -Filter $fileFilter -File})
    
                    foreach($projectFile in $projectFiles) {
                    
                        if (-not $visited.Add($projectFile.FullName)) {
                            continue
                        }
    
                        Write-Information "Building project: $($projectFile.FullName)"
    
                        $msbuildCommand = "&""$(join-path $buildTools "msbuild.exe")"" /v:minimal /nologo /consoleloggerparameters:""NoSummary;ForceNoAlign"" /t:""$effectiveTarget"" "
    
                        $ref.EffectiveConfiguration.getProperties("BuildProperties") | Foreach-Object {
                            $msbuildCommand = "$msbuildCommand/p:$_=""$($ref.EffectiveConfiguration.getProperty("BuildProperties", $_))"" "
                        }
    
                        $msbuildCommand = "$msbuildCommand""$($projectFile.FullName)"""
    
                        if ($pscmdlet.ShouldProcess("$($ref.Class)/$ref", "MSBuild:$effectiveTarget")) {
    
                            $errorCount = 0
                            $msbuildCommand | Invoke-Expression | Foreach-Object {
            
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
                                    Write-Verbose $_.TrimStart()
                                }
                            }
    
                            if (($errorCount -le 0) -and ($LASTEXITCODE -ne 0)) {
                                Write-Error "Failed to build project: $($projectFile.FullName)"
                                Return
                            }
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