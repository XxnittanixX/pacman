class XmlPropertyContainer {

    hidden [string] $_Path = $Path

    XmlPropertyContainer ([string] $Path) {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            Write-Error "Path can't be empty"
            Return
        }

        $this._Path  = $Path
    }

    [string] getProperty([string] $Property) { 
        return $this.getProperty($null, $Property)
    }
    [string] getProperty([string] $Group, [string] $Property) {
        $xml = $this.loadPropertyContainer()
        $propertyNode = $this.findPropertyNode($xml, $Property, $Group)

        if ($propertyNode -eq $null) {
            return $null
        }

        return $propertyNode.InnerText
    }

    [void] setProperty([string] $Property, [string] $Value) { 
        $this.setProperty($null, $Property, $Value)
    }
    [void] setProperty([string] $Group, [string] $Property, [string] $Value) {
        $xml = $this.loadPropertyContainer()
        $propertyNode = $this.findPropertyNode($xml, $Property, $Group)

        if ($propertyNode -eq $null) {
            return
        }

        if ([string]::IsNullOrEmpty($Value)) {
            $null = $propertyNode.ParentNode.RemoveChild($propertyNode)
        } else {
            $propertyNode.InnerText = $Value
        }
    
        $stringWriter = New-Object System.IO.Stringwriter
        $xmlWriter = New-Object System.Xml.XmlTextWriter($stringWriter)

        try {
            $xmlWriter.Formatting = [System.Xml.Formatting]::Indented
            $xml.WriteTo($xmlWriter)
            $outString = $stringWriter.ToString()

            Set-Content -Encoding UTF8 -Path $this._Path -Value $outString
        }
        finally {
            $xmlWriter.Dispose()
            $stringWriter.Dispose()
        }
    }

    [string[]] getGroups() {
        $xml = $this.loadPropertyContainer()
        $project = $xml.Project

        $propertyGroup = $null
        $propertyGroupLabelAttribute = $null

        if ($project -eq $null) {
            Write-Error "Invalid XML root"
            return $null
        }

        $groupList = New-Object System.Collections.ArrayList

        for($i = 0; $i -lt $project.ChildNodes.Count; $i++) {
            $propertyGroup = $project.ChildNodes[$i]

            if ($propertyGroup.LocalName -ne "PropertyGroup") {
                $propertyGroup = $null
            }
            else {
                for($j =0; $j -lt $propertyGroup.Attributes.Count; $j++) {
                    $propertyGroupLabelAttribute = $propertyGroup.Attributes[$j]

                    if ($propertyGroupLabelAttribute.LocalName -ne "Label") {
                        $propertyGroupLabelAttribute = $null
                    }
                    else {
                        break
                    }
                }

                if ($propertyGroupLabelAttribute -ne $null) {
                    $propertyGroupLabel = $propertyGroupLabelAttribute.Value

                    if ([string]::IsNullOrWhiteSpace($propertyGroupLabel)) {
                        $propertyGroupLabel = $null
                    }
                }
                else {
                    $propertyGroupLabel = $null
                }

                if (-not [string]::IsNullOrWhiteSpace($propertyGroupLabel)) {
                    $groupList.Add($propertyGroupLabel)
                }
            }
        }

        return $groupList.ToArray("System.String")
    }

    [string[]] getProperties() {
        return $this.getProperties($null);
    }
    [string[]] getProperties($Group) {
        
        if ([string]::IsNullOrWhiteSpace($Group)) {
            $Group = $null
        }

        $xml = $this.loadPropertyContainer()
        $propertyGroup = $this.findGroupNode($Xml, $Group)
        $propertyList = New-Object System.Collections.ArrayList

        if ($propertyGroup -eq $null) {
            return @()
        }

        for($i = 0; $i -lt $propertyGroup.ChildNodes.Count; $i++) {
            $propertyNode = $propertyGroup.ChildNodes[$i]
            $propertyList.Add($propertyNode.LocalName)
        }

        return $propertyList.ToArray("System.String")
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

    hidden [System.Xml.XmlDocument] loadPropertyContainer() {
        if (-not (Test-Path $this._Path -PathType Leaf)) {
            $xml = [xml]"<?xml version=""1.0"" encoding=""utf-8""?>`r`n<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003"">`r`n</Project>"
        }
        else {
            $xml = [xml](get-content -Path $this._Path)
        }

        return $xml
    }
    hidden [System.Xml.XmlElement] findGroupNode([xml] $Xml, [string] $Group = $null){
        $project = $xml.Project

        $propertyGroup = $null
        $propertyGroupLabelAttribute = $null

        if ($project -eq $null) {
            Write-Error "Invalid XML root"
            return $null
        }

        for($i = 0; $i -lt $project.ChildNodes.Count; $i++) {
            $propertyGroup = $project.ChildNodes[$i]

            if ($propertyGroup.LocalName -ne "PropertyGroup") {
                $propertyGroup = $null
            }
            else {
                for($j =0; $j -lt $propertyGroup.Attributes.Count; $j++) {
                    $propertyGroupLabelAttribute = $propertyGroup.Attributes[$j]

                    if ($propertyGroupLabelAttribute.LocalName -ne "Label") {
                        $propertyGroupLabelAttribute = $null
                    }
                    else {
                        break
                    }
                }

                if ($propertyGroupLabelAttribute -ne $null) {
                    $propertyGroupLabel = $propertyGroupLabelAttribute.Value

                    if ([string]::IsNullOrWhiteSpace($propertyGroupLabel)) {
                        $propertyGroupLabel = $null
                    }
                }
                else {
                    $propertyGroupLabel = $null
                }

                if (-not [string]::Equals($propertyGroupLabel, $Group, "InvariantCultureIgnoreCase")) {
                    $propertyGroup = $null
                }
                else {
                    break
                }
            }
        }

        if ($propertyGroup -eq $null) {
            $propertyGroup = $xml.CreateElement("PropertyGroup", "http://schemas.microsoft.com/developer/msbuild/2003")

            if (-not [string]::IsNullOrWhiteSpace($Group)) {
                $null = $project.AppendChild($propertyGroup)
                $propertyGroup.SetAttribute("Label", "", $Group)
            }
            else {
                $null = $project.PrependChild($propertyGroup)
            }
        }

        return $propertyGroup
    }
    hidden [System.Xml.XmlElement] findPropertyNode([xml] $Xml, [string] $Property, [string] $Group = $null) {

        if ([string]::IsNullOrWhiteSpace($Group)) {
            $Group = $null
        }

        $propertyNode = $null
        $propertyGroup = $this.findGroupNode($Xml, $Group)

        if ($propertyGroup -eq $null) {
            return $null
        }

        for($i = 0; $i -lt $propertyGroup.ChildNodes.Count; $i++) {
            $propertyNode = $propertyGroup.ChildNodes[$i]

            if (-not [string]::Equals($propertyNode.LocalName, $Property, "InvariantCultureIgnoreCase")) {
                $propertyNode = $null
            }
            else {
                break
            }
        }

        if ($propertyNode -eq $null) {
            $propertyNode = $xml.CreateElement("$Property", "http://schemas.microsoft.com/developer/msbuild/2003")
            $null = $propertyGroup.AppendChild($propertyNode)
        }

        return $propertyNode
    }
}

function New-XmlPropertyContainer { 
	param([Parameter(Mandatory = $true, Position = 0)] [string] $Path)
	return New-Object XmlPropertyContainer -ArgumentList @($Path) 
}

Export-ModuleMember "New-XmlPropertyContainer"
