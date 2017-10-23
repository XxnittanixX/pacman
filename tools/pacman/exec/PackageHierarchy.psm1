class HierarchyLevel {
	[ValidateNotNullOrEmpty()] [String]               $Name
	[ValidateNotNullOrEmpty()] [IO.DirectoryInfo]     $Directory
	[ValidateNotNullOrEmpty()]                        $Configuration
	
	[string] getEffectiveProperty([string] $Property) {

		$value = $this.Configuration.getProperty($Property)

		if (-not [string]::IsNullOrEmpty($value)) { return $value }

		return $null
	}
	
	[string] ToString() {
		return $this.Name
	}
}

class PackageRepository : HierarchyLevel {
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
	[ValidateNotNullOrEmpty()] [PackageRepository] $Repository
	[ValidateNotNullOrEmpty()] [PackageClass]      $Class

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

function Get-PackageRepository {

	$SolutionRoot = Join-Path $global:System.RootDirectory "src"

	$PackageRepositoryFolder = [IO.DirectoryInfo] $SolutionRoot
	$PackageRepositoryConfiguration = New-XmlPropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.props")

	$PackageRepository = [PackageRepository] @{
		Name = $PackageRepositoryFolder.Parent.Name # <Repository>\src\<Class>\<Package>
		Configuration = $PackageRepositoryConfiguration
		Directory = $PackageRepositoryFolder
	}

	return $PackageRepository
}

function Get-PackageClass {
	param(
		[Parameter(Mandatory = $false, Position = 0)] [string] $Filter = $null
	)

	$SolutionRoot = Join-Path $global:System.RootDirectory "src"

	if ([string]::IsNullOrWhiteSpace($Filter)) {
		$Filter = "*"
	}

	$Candidates = @(Get-ChildItem -Path $SolutionRoot -Directory -Filter $Class)

	foreach($Candidate in $Candidates) {

		$PackageClassFolder = [IO.DirectoryInfo]$Candidate
		$PackageClassConfiguration = New-XmlPropertyContainer (Join-Path $PackageClassFolder.FullName "package.props")
		
		$PackageRepositoryFolder = $PackageClassFolder.Parent
		$PackageRepositoryConfiguration = New-XmlPropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.props")
		
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

		Write-Output $PackageClass
	}
}

function Get-Package {
	param(
		[Parameter(Mandatory = $false, Position = 0)] [string] $Filter 
	)

	$SolutionRoot = Join-Path $global:System.RootDirectory "src"

	if ([string]::IsNullOrWhiteSpace($Filter)) {
		$Filter = "*"
	}

	if ($Filter.Contains("/")) {
		$Tokens = $Filter.Split(@("/"), 2, [StringSplitOptions]::RemoveEmptyEntries)

		if ($Tokens.Length -eq 1) {
			$Name = $Tokens[0]
			$Class = "*"
		} else {
			$Name = $Tokens[1]
			$Class = $Tokens[0]
		}
	} else {
		$Name = $Filter
		$Class = "*"
	}

	$Candidates = @( `
		Get-ChildItem -Path $SolutionRoot -Directory -Filter $Class | % { `
		Get-ChildItem -Path $_.FullName -Directory -Filter $Name })

	foreach($Candidate in $Candidates) {
		
		$PackageFolder = [IO.DirectoryInfo]$Candidate
		$PackageConfiguration = New-XmlPropertyContainer (Join-Path $PackageFolder.FullName "package.props")
		
		$PackageClassFolder = $PackageFolder.Parent
		$PackageClassConfiguration = New-XmlPropertyContainer (Join-Path $PackageClassFolder.FullName "package.props")
		
		$PackageRepositoryFolder = $PackageClassFolder.Parent
		$PackageRepositoryConfiguration = New-XmlPropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.props")
		
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
		
		Write-Output $Package
	}
}

function Get-PackageProperty {
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)] [HierarchyLevel] $Node,
		[Parameter(Mandatory = $true, Position = 0)] [string] $Property
	)
	
	process {
		Write-Output $Node.getEffectiveProperty($Property)
	}
}

function Set-PackageProperty {
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)] [HierarchyLevel] $Node,
		[Parameter(Mandatory = $true, Position = 0)] [string] $Property,
		[Parameter(Mandatory = $false, Position = 1)] [string] $Value
	)
	
	process {
		$Node.Configuration.setProperty($Property, $Value)
	}
}

Export-ModuleMember -Function @(
	"Get-Package",
	"Get-PackageClass",
	"Get-PackageRepository",
	"Get-PackageProperty",
	"Set-PackageProperty"
)