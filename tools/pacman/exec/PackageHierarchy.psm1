class HierarchicalConfigurationContainer {

	hidden [Array] $_Containers
	
	HierarchicalConfigurationContainer ([Array] $Containers) {
		$this._Containers = @($Containers)
	}
	
	[string] getProperty([string] $Property) { 
		return $this.getProperty($null, $Property)
	}
	[string] getProperty([string] $Group, [string] $Property) {
		
		foreach($container in $this._Containers) {
			$value = $container.getProperty($Group, $Property);
			if (-not [string]::IsNullOrEmpty($value)) {
				return $value
			}
		}
		
		return $null
	}

	[string[]] getGroups() {

		$groupList = New-Object "System.Collections.Generic.HashSet[System.String]"

		foreach($container in $this._Containers) {
			foreach($group in $container.getGroups()) {
				$null = $groupList.Add($group)
			}
		}

		return $groupList
	}

	[string[]] getProperties() {
		return $this.getProperties($null);
	}
	[string[]] getProperties($Group) {
	
		$propertyList = New-Object "System.Collections.Generic.HashSet[System.String]"

		foreach($container in $this._Containers) {
			foreach($property in $container.getProperties($Group)) {
				$null = $propertyList.Add($property)
			}
		}

		return $propertyList
	}
	
	[object] getObject() {
		
		$obj = $this.getObject($null)

		foreach($group in $this.getGroups()) {
			Add-Member -InputObject $obj -MemberType NoteProperty -Name $group -Value ($this.getObject($group))
		}

		return $obj
	}
	[object] getObject([string] $Group) {
	
		$obj = New-Object PSObject

		foreach($property in $this.getProperties($Group)) {
			Add-Member -InputObject $obj -MemberType NoteProperty -Name $property -Value ($this.getProperty($Group, $property))
		}

		return $obj
	}

	[String] ToString() {
		return $this._Containers[0].ToString()
	}
}

class HierarchyLevel {
	[ValidateNotNullOrEmpty()] [String]               $Name
	[ValidateNotNullOrEmpty()] [IO.DirectoryInfo]     $Directory
	
	[ValidateNotNullOrEmpty()] $Configuration
	[ValidateNotNullOrEmpty()] $EffectiveConfiguration                    
	
	[string] ToString() {
		return $this.Name
	}
}

class PackageRepository : HierarchyLevel {
}

class PackageClass : HierarchyLevel {
	[ValidateNotNullOrEmpty()] [PackageRepository] $Repository
}

class Package : HierarchyLevel {
	[ValidateNotNullOrEmpty()] [PackageRepository] $Repository
	[ValidateNotNullOrEmpty()] [PackageClass]      $Class
}

function Get-PackageRepository {

	$SolutionRoot = Join-Path $global:System.RootDirectory "src"

	$PackageRepositoryFolder = [IO.DirectoryInfo] $SolutionRoot
	$PackageRepositoryConfiguration = New-XmlPropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.props")

	$PackageRepository = [PackageRepository] @{
		Name = $PackageRepositoryFolder.Parent.Name # <Repository>\src\<Class>\<Package>
		Directory = $PackageRepositoryFolder
		Configuration = $PackageRepositoryConfiguration
		EffectiveConfiguration = New-Object "HierarchicalConfigurationContainer" -ArgumentList @(,@($PackageRepositoryConfiguration))
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
			Directory = $PackageRepositoryFolder
			Configuration = $PackageRepositoryConfiguration
			EffectiveConfiguration = New-Object "HierarchicalConfigurationContainer" -ArgumentList @(,@($PackageRepositoryConfiguration))
		}
		
		$PackageClass = [PackageClass] @{
			Name = $PackageClassFolder.Name
			Directory = $PackageClassFolder
			Repository = $PackageRepository
			Configuration = $PackageClassConfiguration
			EffectiveConfiguration = New-Object "HierarchicalConfigurationContainer" -ArgumentList @(,@($PackageClassConfiguration, $PackageRepositoryConfiguration))
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
			Directory = $PackageRepositoryFolder
			Configuration = $PackageRepositoryConfiguration
			EffectiveConfiguration = New-Object "HierarchicalConfigurationContainer" -ArgumentList @(,@($PackageRepositoryConfiguration))
		}
		
		$PackageClass = [PackageClass] @{
			Name = $PackageClassFolder.Name
			Directory = $PackageClassFolder
			Repository = $PackageRepository
			Configuration = $PackageClassConfiguration
			EffectiveConfiguration = New-Object "HierarchicalConfigurationContainer" -ArgumentList @(,@($PackageClassConfiguration, $PackageRepositoryConfiguration))
		}
		
		$Package = [Package] @{
			Name = $PackageFolder.Name
			Directory = $PackageFolder
			Repository = $PackageRepository
			Class = $PackageClass
			Configuration = $PackageConfiguration
			EffectiveConfiguration = New-Object "HierarchicalConfigurationContainer" -ArgumentList @(,@($PackageConfiguration, $PackageClassConfiguration, $PackageRepositoryConfiguration))
		}
		
		Write-Output $Package
	}
}

function Get-PackageProperty {
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)] [HierarchyLevel] $Node,
		[Parameter(Mandatory = $true, Position = 0)] [string] $Property,
		[Parameter(Mandatory = $false)] [string] $Group = $null
	)
	
	process {
		Write-Output $Node.EffectiveConfiguration.getProperty($Group, $Property)
	}
}

function Get-PackageConfiguration {
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)] [HierarchyLevel] $Node,
		[Parameter(Mandatory = $false)] [string] $Group = $null
	)
	
	process {
		if ($Group -eq $null) {
			Write-Output $Node.EffectiveConfiguration.getObject()
		} 
		else {
			Write-Output $Node.EffectiveConfiguration.getObject($Group)
		}
	}
}

function Set-PackageProperty {
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)] [HierarchyLevel] $Node,
		[Parameter(Mandatory = $true, Position = 0)] [string] $Property,
		[Parameter(Mandatory = $false, Position = 1)] [string] $Value,
		[Parameter(Mandatory = $false)] [string] $Group = $null
	)
	
	process {
		$Node.Configuration.setProperty($Group, $Property, $Value)
	}
}

Export-ModuleMember -Function @(
	"Get-Package",
	"Get-PackageClass",
	"Get-PackageRepository",
	"Get-PackageProperty",
	"Get-PackageConfiguration",
	"Set-PackageProperty"
)