class HierarchyLevel {
    [ValidateNotNullOrEmpty()] [String]               $Name
    [ValidateNotNullOrEmpty()] [IO.DirectoryInfo]     $Directory
    [ValidateNotNullOrEmpty()]                        $Configuration
}

class PackageRepository : HierarchyLevel {
    [string] getEffectiveProperty([string] $Property) {

        $packageRepositoryCfg = $this.Repository.Configuration.getProperty($Property)

        if (-not [string]::IsNullOrEmpty($packageRepositoryCfg)) { return $packageRepositoryCfg }

        return $null
    }
}

class PackageClass : HierarchyLevel {
    [ValidateNotNullOrEmpty()] [PackageRepository] $Repository

    [string] getEffectiveProperty([string] $Property) {

        $packageClassCfg = $this.Configuration.getProperty($Property)
        $packageRepositoryCfg = $this.Repository.Configuration.getProperty($Property)

        if (-not [string]::IsNullOrEmpty($packageClassCfg)) { return $packageClassCfg }
        if (-not [string]::IsNullOrEmpty($packageRepositoryCfg)) { return $packageRepositoryCfg }

        return $null
    }
}

class Package : HierarchyLevel {
    [ValidateNotNullOrEmpty()] [PackageClass]      $Class
    [ValidateNotNullOrEmpty()] [PackageRepository] $Repository

    [string] getEffectiveProperty([string] $Property) {

        $packageCfg = $this.Configuration.getProperty($Property)
        $packageClassCfg = $this.Class.Configuration.getProperty($Property)
        $packageRepositoryCfg = $this.Repository.Configuration.getProperty($Property)

        if (-not [string]::IsNullOrEmpty($packageCfg)) { return $packageCfg }
        if (-not [string]::IsNullOrEmpty($packageClassCfg)) { return $packageClassCfg }
        if (-not [string]::IsNullOrEmpty($packageRepositoryCfg)) { return $packageRepositoryCfg }

        return $null
    }
}

function Get-Package {
    param(
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true)] [string] $Id = $null
    )

    $SolutionRoot = Join-Path $Repository.RootDirectory "src"

    if ([string]::IsNullOrWhiteSpace($Id)) {
        $Id = "*"
    }

    if ($Id.Contains("/")) {
        $Tokens = $Id.Split(@("/"), 2, [StringSplitOptions]::RemoveEmptyEntries)

        if ($Tokens.Length -eq 1) {
            $Name = $Tokens[0]
            $Class = "*"
        } else {
            $Name = $Tokens[1]
            $Class = $Tokens[0]
        }
    } else {
        $Name = $Id
        $Class = "*"
    }

    $Candidates = @( `
        Get-ChildItem -Path $SolutionRoot -Directory -Filter $Class | % { `
        Get-ChildItem -Path $_.FullName -Directory -Filter $Name })

    if ($Candidates.Length -gt 1) {
        Write-Error "Multiple projects found in $Class/$Name"
        Return
    }
    elseif ($Candidates.Length -eq 0) {
        Write-Error "Could not find package for identifier ""$Class/$Name"""
        Return
    }

    $PackageFolder = [IO.DirectoryInfo]$Candidates[0]
    $PackageConfiguration = New-XmlPropertyContainer (Join-Path $PackageFolder.FullName "package.props")

    $PackageClassFolder = $PackageFolder.Parent
    $PackageClassConfiguration = New-XmlPropertyContainer (Join-Path $PackageClassFolder.FullName "package.props")

    $PackageRepositoryFolder = $PackageClassFolder.Parent
    $PackageRepositoryConfiguration = New-XmlPropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.props")

    $Package = New-Object PSObject
    $PackageClass = New-Object PSObject
    $PackageRepository = New-Object PSObject

    $PackageRepository = [PackageRepository] @{
        Name = $PackageRepositoryFolder.Parent.Name # <Repository>\src\<Class>\<Package>
        Configuration = $PackageRepositoryConfiguration
        Directory = $PackageRepositoryFolder
    }

    $PackageClass = [PackageClass] @{
        Name = $PackageClassFolder.Name
        Configuration = $PackageClassConfiguration
        Directory = $PackageClassFolder
        Repository = $PackageRepository
    }

    $Package = [Package] @{
        Name = $PackageFolder.Name
        Configuration = $PackageConfiguration
        Directory = $PackageFolder
        Repository = $PackageRepository
        Class = $PackageClass
    }

    return $Package
}

Export-ModuleMember -Function @(
    "Get-Package"
)