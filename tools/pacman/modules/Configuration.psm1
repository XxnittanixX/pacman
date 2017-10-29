class PropertyContainer {

    hidden [string] $_Path = $Path

    PropertyContainer ([string] $Path) {
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
        $raw = $this.loadPropertyContainer()
        $propertyNode = $this.findPropertyNode($raw, $Property, $Group)

        if ($propertyNode -eq $null) {
            return $null
        }

        return $propertyNode
    }

    [void] setProperty([string] $Property, [string] $Value) { 
        $this.setProperty($null, $Property, $Value)
    }
    [void] setProperty([string] $Group, [string] $Property, [string] $Value) {
        if ([string]::IsNullOrEmpty($Property)) {
            return
        }

        $object = $this.loadPropertyContainer()
        $node = $object

        if (-not [string]::IsNullOrWhiteSpace($Group)) {
            $members = $object | Get-Member -Type NoteProperty | Where-Object {
                $memberValue = $object | Select-Object -ExpandProperty $_.Name
                $memberType = "System.Object"

                if ($memberValue -ne $null) {
                    $memberType = $memberValue.GetType().Name
                }

                $memberType -eq "PSCustomObject"
            }

            $matchingMember = $members `
                | Where-Object { [string]::Equals($_.Name, "$Group".Trim(), "InvariantCultureIgnoreCase") } `
                | Select-Object -First 1 -ExpandProperty $_.Name

            if ($matchingMember -eq $null) {
                $node = @{}
                $object."$Group" = $node
            } else {
                $node = $object."$Group"
            }
        }

        $members = $node | Get-Member -Type NoteProperty | Foreach-Object {
            $memberValue = $node | Select-Object -ExpandProperty $_.Name
            $memberType = "System.Object"

            if ($memberValue -ne $null) {
                $memberType = $memberValue.GetType().Name
            }

            @{Name = $_.Name; IsGroup = $memberType -eq "PSCustomObject"}
        }

        $matchingMember = $members `
            | Where-Object { [string]::Equals($_.Name, "$Property".Trim(), "InvariantCultureIgnoreCase") } `
            | Select-Object -First 1 -ExpandProperty $_.Name

        if ($matchingMember -eq $null) {
            $node | Add-Member -Type NoteProperty -Name $Property -Value $Value
        } 
        elseif ($matchingMember.IsGroup) {
            throw("""$Property"" is a group and can't be set directly.")
        }
        else {
            $node."$Property" = $Value
        }

        $object | ConvertTo-Json | Set-Content -Path $this._Path
    }

    [string[]] getGroups() {
        $object = $this.loadPropertyContainer()

        if ($object -eq $null) {
            return @()
        }

        $members = $object | Get-Member -Type NoteProperty | Where-Object {
            $memberValue = $object | Select-Object -ExpandProperty $_.Name
            $memberType = "System.Object"

            if ($memberValue -ne $null) {
                $memberType = $memberValue.GetType().Name
            }

            $memberType -eq "PSCustomObject"
        }

        $groupList = New-Object "System.Collections.Generic.HashSet[System.String]"

        foreach($member in $members) {
            $null = $groupList.Add($member.Name)
        }

        return @($groupList)
    }

    [string[]] getProperties() {
        
        $object = $this.loadPropertyContainer()

        if ($object -eq $null) {
            return @()
        }

        $members = $object | Get-Member -Type NoteProperty | Where-Object {
            $memberValue = $object | Select-Object -ExpandProperty $_.Name
            $memberType = "System.Object"

            if ($memberValue -ne $null) {
                $memberType = $memberValue.GetType().Name
            }

            $memberType -ne "PSCustomObject"
        }

        $groupList = New-Object "System.Collections.Generic.HashSet[System.String]"

        foreach($member in $members) {
            $null = $groupList.Add($member.Name)
        }

        return @($groupList)
    }
    [string[]] getProperties($Group) {
        
        $object = $this.findGroupNode($this.loadPropertyContainer(), $Group)

        if ($object -eq $null) {
            return @()
        }

        $members = $object | Get-Member -Type NoteProperty | Where-Object {
            $memberValue = $object | Select-Object -ExpandProperty $_.Name
            $memberType = "System.Object"

            if ($memberValue -ne $null) {
                $memberType = $memberValue.GetType().Name
            }

            $memberType -ne "PSCustomObject"
        }

        $groupList = New-Object "System.Collections.Generic.HashSet[System.String]"

        foreach($member in $members) {
            $null = $groupList.Add($member.Name)
        }

        return @($groupList)
    }

    [object] getObject() {
        return $this.loadPropertyContainer()
    }
    [object] getObject([string] $Group) {
        return $this.findGroupNode($this.loadPropertyContainer(), $Group)
    }

    [String] ToString() {
        return $this._Path
    }

    hidden [object] loadPropertyContainer() {
        if (-not (Test-Path $this._Path -PathType Leaf)) {
            return @{}
        }

        return Get-Content -Raw $this._Path | ConvertFrom-Json
    }
    hidden [object] findGroupNode($object, [string] $Group = $null){

        if ([string]::IsNullOrWhiteSpace($Group)) {
            return @{}
        }

        $members = $object | Get-Member -Type NoteProperty | Where-Object {
            $memberValue = $object | Select-Object -ExpandProperty $_.Name
            $memberType = "System.Object"

            if ($memberValue -ne $null) {
                $memberType = $memberValue.GetType().Name
            }

            $memberType -eq "PSCustomObject"
        }

        $matchingMember = $members `
            | Where-Object { [string]::Equals($_.Name, "$Group".Trim(), "InvariantCultureIgnoreCase") } `
            | Select-Object -First 1 -ExpandProperty $_.Name

        if ($matchingMember -eq $null) {
            return @{}
        }

        return $object | Select-Object -ExpandProperty $matchingMember.Name
    }
    hidden [object] findPropertyNode($object, [string] $Property, [string] $Group = $null) {

        if (-not [string]::IsNullOrWhiteSpace($Group)) {
            $object = $this.findGroupNode($object, $Group)
        }

        $members = $object | Get-Member -Type NoteProperty | Where-Object {
            $memberValue = $object | Select-Object -ExpandProperty $_.Name
            $memberType = "System.Object"

            if ($memberValue -ne $null) {
                $memberType = $memberValue.GetType().Name
            }

            $memberType -ne "PSCustomObject"
        }

        $matchingMember = $members `
            | Where-Object { [string]::Equals($_.Name, "$Property".Trim(), "InvariantCultureIgnoreCase") } `
            | Select-Object -First 1 -ExpandProperty $_.Name

        if ($matchingMember -eq $null) {
            return $null
        }

        return $object | Select-Object -ExpandProperty $matchingMember.Name
    }
}

function New-PropertyContainer { 
    param([Parameter(Mandatory = $true, Position = 0)] [string] $Path, [switch] $Force)
    
    if ($Force -and -not (Test-Path $Path -PathType Leaf)){
        [IO.File]::WriteAllText($Path, "{`r`n}")
    }

	return New-Object PropertyContainer -ArgumentList @($Path) 
}

Export-ModuleMember -Function @(
    "New-PropertyContainer"
)