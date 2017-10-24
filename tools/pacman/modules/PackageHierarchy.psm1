class EffectiveConfigurationContainer {

	hidden $_Metadata
	hidden [Array] $_Containers
	
	EffectiveConfigurationContainer ([String] $OwnerId, [Array] $Containers) {
		$this._Containers = @($Containers)
		$this._Metadata = @{
			Package = $OwnerId
		}
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
		
		if ([string]::IsNullOrEmpty($Group)) {
			foreach($key in $this._Metadata.Keys) {
				Add-Member -InputObject $obj -MemberType NoteProperty -Name $key -Value ($this._Metadata[$key])
			}
		}

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
	
	[Package[]] getPackages() {
		throw("Must be used in overriden class")
	}
	
	[string] ToString() {
		return $this.Name
	}
}

class PackageRepository : HierarchyLevel {
	[Package[]] getPackages() {
		return @(Get-Package -Filter "$($this.Directory.Name):*/*")
	}
}

class PackageClass : HierarchyLevel {
	[ValidateNotNullOrEmpty()] [PackageRepository] $Repository
	
	[Package[]] getPackages() {
		return @(Get-Package -Filter "$($this.Repository.Directory.Name):$($this.Name)/*")
	}
}

class Package : HierarchyLevel {
	[ValidateNotNullOrEmpty()] [PackageRepository] $Repository
	[ValidateNotNullOrEmpty()] [PackageClass]      $Class
	
	[Package[]] getPackages() {
		return @($this)
	}
}

function Get-PackageRepository {
	param(
		[Parameter(Mandatory = $false, Position = 0)] [string] $Id
	)
	
	if ([string]::IsNullOrWhiteSpace($Id)) {
		$Id = $global:System.DefaultRepository
	}

	$SolutionRoot = Join-Path $global:System.RootDirectory $Id
	
	if ($Id -ne $global:System.DefaultRepository) {
		$Prefix = "$($Id):"
		$Suffix = " ($($Id))"
	}
	else {
		$Prefix = ""
		$Suffix = ""
	}
	
	$PackageRepositoryFolder = [IO.DirectoryInfo] $SolutionRoot
	$PackageRepositoryConfiguration = New-XmlPropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.props")
	
	$PackageRepository = [PackageRepository] @{
		Name = "$($PackageRepositoryFolder.Parent.Name)$Suffix"
		Directory = $PackageRepositoryFolder
		Configuration = $PackageRepositoryConfiguration
		EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @($Prefix.TrimEnd(":"),@($PackageRepositoryConfiguration))
	}

	return $PackageRepository
}

function Test-Validity { 
	param([string] $Id, [char[]] $IllegalChars = [IO.Path]::GetInvalidFileNameChars()) 
	return("$Id".ToCharArray()|?{(New-Object string @(,$IllegalChars)).Contains("$_")}).Count -eq 0
}

function Get-PackageClass {
	param(
		[Parameter(Mandatory = $false, Position = 0)] [string] $Filter = $null
	)

	if ([string]::IsNullOrWhiteSpace($Filter)) {
		$Filter = "*"
	}
	
	if ($Filter.Contains(":")) {
		$Tokens = $Filter.Split(@(":"), 2, [StringSplitOptions]::RemoveEmptyEntries)

		if ($Tokens.Length -eq 1) {
			$Filter = $Tokens[0]
			$RepositoryId = $global:System.DefaultRepository
		} else {
			$Filter = $Tokens[1]
			$RepositoryId = $Tokens[0]
		}
	} else {
		$RepositoryId = $global:System.DefaultRepository
	}
	
	$SolutionRoot = Join-Path $global:System.RootDirectory $RepositoryId
	
	if (-not (Test-Path $SolutionRoot -PathType Container)) {
		return
	}

	$Candidates = @(Get-ChildItem -Path $SolutionRoot -Directory -Filter $Filter)
	
	if ($RepositoryId -ne $global:System.DefaultRepository) {
		$Prefix = "$($RepositoryId):"
		$Suffix = " ($($RepositoryId))"
	}
	else {
		$Prefix = ""
		$Suffix = ""
	}

	if ($Candidates.Length -eq 0) {
		if (-not (Test-Validity -Id $Filter -IllegalChars @("*", "?"))) {
			echo $Filter
			return
		}

		$PackageClassFolder = [IO.DirectoryInfo] (Join-Path $SolutionRoot $Filter)
		$PackageClassConfiguration = New-XmlPropertyContainer (Join-Path $PackageClassFolder.FullName "package.props")
		
		$PackageRepositoryFolder = [IO.DirectoryInfo] $SolutionRoot
		$PackageRepositoryConfiguration = New-XmlPropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.props")
		
		$PackageRepository = [PackageRepository] @{
			Name = "$($PackageRepositoryFolder.Parent.Name)$Suffix"
			Directory = $PackageRepositoryFolder
			Configuration = $PackageRepositoryConfiguration
			EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @($Prefix.TrimEnd(":"),@($PackageRepositoryConfiguration))
		}
		
		$PackageClass = [PackageClass] @{
			Name = $PackageClassFolder.Name
			Directory = $PackageClassFolder
			Repository = $PackageRepository
			Configuration = $PackageClassConfiguration
			EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @("$Prefix$($PackageClassFolder.Name)/*",@($PackageClassConfiguration, $PackageRepositoryConfiguration))
		}

		return @($PackageClass)
	}

	foreach($Candidate in $Candidates) {

		$PackageClassFolder = [IO.DirectoryInfo]$Candidate
		$PackageClassConfiguration = New-XmlPropertyContainer (Join-Path $PackageClassFolder.FullName "package.props")
		
		$PackageRepositoryFolder = $PackageClassFolder.Parent
		$PackageRepositoryConfiguration = New-XmlPropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.props")
		
		$PackageRepository = [PackageRepository] @{
			Name = "$($PackageRepositoryFolder.Parent.Name)$Suffix"
			Directory = $PackageRepositoryFolder
			Configuration = $PackageRepositoryConfiguration
			EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @($Prefix.TrimEnd(":"),@($PackageRepositoryConfiguration))
		}
		
		$PackageClass = [PackageClass] @{
			Name = $PackageClassFolder.Name
			Directory = $PackageClassFolder
			Repository = $PackageRepository
			Configuration = $PackageClassConfiguration
			EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @("$Prefix$($PackageClassFolder.Name)/*",@($PackageClassConfiguration, $PackageRepositoryConfiguration))
		}

		Write-Output $PackageClass
	}
}

function Get-Package {
	param(
		[Parameter(Mandatory = $false, Position = 0)] [string] $Filter 
	)

	if ([string]::IsNullOrWhiteSpace($Filter)) {
		$Filter = "*"
	}
	
	if ([string]::IsNullOrWhiteSpace($Filter)) {
		$Filter = "*"
	}
	
	if ($Filter.Contains(":")) {
		$Tokens = $Filter.Split(@(":"), 2, [StringSplitOptions]::RemoveEmptyEntries)

		if ($Tokens.Length -eq 1) {
			$Filter = $Tokens[0]
			$RepositoryId = $global:System.DefaultRepository
		} else {
			$Filter = $Tokens[1]
			$RepositoryId = $Tokens[0]
		}
	} else {
		$RepositoryId = $global:System.DefaultRepository
	}
	
	$SolutionRoot = Join-Path $global:System.RootDirectory $RepositoryId
	
	if (-not (Test-Path $SolutionRoot -PathType Container)) {
		return
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
		
	if ($RepositoryId -ne $global:System.DefaultRepository) {
		$Prefix = "$($RepositoryId):"
		$Suffix = " ($($RepositoryId))"
	}
	else {
		$Prefix = ""
		$Suffix = ""
	}

	if ($Candidates.Length -eq 0) {
		if (-not (Test-Validity -Id "$Class\$Name" -IllegalChars @("*", "?"))) {
			echo $Filter
			return
		}

		$PackageFolder = [IO.DirectoryInfo] (Join-Path $SolutionRoot "$Class\$Name")
		$PackageConfiguration = New-XmlPropertyContainer (Join-Path $PackageFolder.FullName "package.props")

		$PackageClassFolder = [IO.DirectoryInfo] (Join-Path $SolutionRoot "$Class")
		$PackageClassConfiguration = New-XmlPropertyContainer (Join-Path $PackageClassFolder.FullName "package.props")
		
		$PackageRepositoryFolder = [IO.DirectoryInfo] $SolutionRoot
		$PackageRepositoryConfiguration = New-XmlPropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.props")
		
		$PackageRepository = [PackageRepository] @{
			Name = "$($PackageRepositoryFolder.Parent.Name)$Suffix"
			Directory = $PackageRepositoryFolder
			Configuration = $PackageRepositoryConfiguration
			EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @($Prefix.TrimEnd(":"),@($PackageRepositoryConfiguration))
		}
		
		$PackageClass = [PackageClass] @{
			Name = $PackageClassFolder.Name
			Directory = $PackageClassFolder
			Repository = $PackageRepository
			Configuration = $PackageClassConfiguration
			EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @("$Prefix$($PackageClassFolder.Name)/*",@($PackageClassConfiguration, $PackageRepositoryConfiguration))
		}

		$Package = [Package] @{
			Name = $PackageFolder.Name
			Directory = $PackageFolder
			Repository = $PackageRepository
			Class = $PackageClass
			Configuration = $PackageConfiguration
			EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @("$Prefix$($PackageClassFolder.Name)/$($PackageFolder.Name)",@($PackageConfiguration, $PackageClassConfiguration, $PackageRepositoryConfiguration))
		}

		return @($Package)
	}

	foreach($Candidate in $Candidates) {
		
		$PackageFolder = [IO.DirectoryInfo]$Candidate
		$PackageConfiguration = New-XmlPropertyContainer (Join-Path $PackageFolder.FullName "package.props")
		
		$PackageClassFolder = $PackageFolder.Parent
		$PackageClassConfiguration = New-XmlPropertyContainer (Join-Path $PackageClassFolder.FullName "package.props")
		
		$PackageRepositoryFolder = $PackageClassFolder.Parent
		$PackageRepositoryConfiguration = New-XmlPropertyContainer (Join-Path $PackageRepositoryFolder.FullName "package.props")
		
		$PackageRepository = [PackageRepository] @{
			Name = "$($PackageRepositoryFolder.Parent.Name)$Suffix"
			Directory = $PackageRepositoryFolder
			Configuration = $PackageRepositoryConfiguration
			EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @($Prefix.TrimEnd(":"),@($PackageRepositoryConfiguration))
		}
		
		$PackageClass = [PackageClass] @{
			Name = $PackageClassFolder.Name
			Directory = $PackageClassFolder
			Repository = $PackageRepository
			Configuration = $PackageClassConfiguration
			EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @("$Prefix$($PackageClassFolder.Name)/*",@($PackageClassConfiguration, $PackageRepositoryConfiguration))
		}
		
		$Package = [Package] @{
			Name = $PackageFolder.Name
			Directory = $PackageFolder
			Repository = $PackageRepository
			Class = $PackageClass
			Configuration = $PackageConfiguration
			EffectiveConfiguration = New-Object "EffectiveConfigurationContainer" -ArgumentList @("$Prefix$($PackageClassFolder.Name)/$($PackageFolder.Name)",@($PackageConfiguration, $PackageClassConfiguration, $PackageRepositoryConfiguration))
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

function Initialize-Package {
	[CmdLetBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)] [Package] $Package,
		[Parameter(Position = 0, Mandatory = $false)] [string] $Template
	)

	$defaultTemplate = $Package.Class.EffectiveConfiguration.getProperty("DefaultTemplate")

	if ([string]::IsNullOrWhiteSpace($Template)) {
		$Template = $defaultTemplate
	}

	$templateSearchPaths = @(
		"templates",
		"tools\pacman\templates"
	)
	$templateExtensions = @(
		"template",
		"zip"
	)

	$foundTemplateFile = $null

	if(-not [string]::IsNullOrWhiteSpace($Template)){
		foreach($templateSearchPath in $templateSearchPaths) {
			foreach($templateExtension in $templateExtensions) { 
				
				$templateFile = Join-Path $global:System.RootDirectory "$templateSearchPath\$Template.$templateExtension"

				if (-not (Test-Path $templateFile -PathType Leaf)) {
					continue
				}

				$foundTemplateFile = $templateFile
				break
			}
			
			if ($foundTemplateFile -ne $null) {
				break
			}
		}

		if ($foundTemplateFile -eq $null) {
			Write-Error "Unable to find template ""$Template""."
			return
		}
	}

	if ($pscmdlet.ShouldProcess("$($Package.Class)/$Package", "Init:CreateDirectory")) {
		$null = $Package.Directory.Create()
	}

	if ($foundTemplateFile -ne $null) {
		if ($pscmdlet.ShouldProcess("$($Package.Class)/$Package", "Init:ExpandTemplate(""$foundTemplateFile"")")) {
			Expand-TemplatePackage -TemplateFile $foundTemplateFile -Destination $Package.Directory.FullName
		}
	}
}

Set-Alias "pkg" "Get-Package"
Set-Alias "pcls" "Get-PackageClass"
Set-Alias "repo" "Get-PackageRepository"
Set-Alias "prop" "Get-PackageProperty"
Set-Alias "props" "Get-PackageConfiguration"
Set-Alias "init" "Initialize-Package"

Export-ModuleMember -Function @(
	"Get-Package",
	"Get-PackageClass",
	"Get-PackageRepository",
	"Get-PackageProperty",
	"Get-PackageConfiguration",
	"Set-PackageProperty",
	"Initialize-Package"
) -Alias @(
	"pkg",
	"pcls",
	"repo",
	"prop",
	"props",
	"init"
)