class PropertyContainer {

    hidden [string] $_Path
    hidden [object] $_ChildName
    hidden [PropertyContainer] $_Owner
    hidden [PSCustomObject] $_CachedModel

    PropertyContainer ([string] $Path) {
        if ([string]::IsNullOrWhiteSpace($Path)) {
            throw("Path can't be empty")
        }

        $this._Path = [IO.Path]::GetFullPath($Path)
    }

    [object] getProperty([string] $Property) { 
        if ([string]::IsNullOrWhiteSpace($Property)) {
            throw("Property name can't be empty")
        }

        $node = $this.getObject()
        return $this.getChildOrValue($node, $Property)
    }
    [void] setProperty([string] $Property, [object] $Value) { 
        if ([string]::IsNullOrWhiteSpace($Property)) {
            throw("Property name can't be empty")
        }

        $node = $this.getObject()

        if ($Value -is [System.Collections.Hashtable]) {
            $Value = [PSCustomObject] $Value
        }

        $node | Add-Member -MemberType NoteProperty -Force -Name $Property -Value $Value
        $this.saveRootNode();
    }

    [PropertyContainer] getChild([string] $Child){
        if ([string]::IsNullOrWhiteSpace($Child)) {
            throw("Child name can't be empty")
        }

        return [PropertyContainer]::new($this, $Child)
    }
    [PSCustomObject] getObject() {
        return $this.readCurrentNode($false)
    }
    [string] getNodePath(){
        if ($this._Owner -ne $null) {
            return "$($this._Owner.getNodePath())/$($this._ChildName)"
        }
        return [string]::Empty
    }
    [string] getTargetPath() {
        if ([string]::IsNullOrWhiteSpace($this._Path)) {
            return $this._Owner.getTargetPath()
        }
        return $this._Path
    }

    [string] ToString() {
        return "$($this.getTargetPath()):/$($this.getNodePath().TrimStart("/"))"
    }

    hidden PropertyContainer ([PropertyContainer] $Owner, [string] $ChildName) {
        if ($Owner -eq $null) {
            throw("Owner can't be empty")
        }
        if ($ChildName -eq $null) {
            throw("Child name can't be empty")
        }

        $this._Owner = $Owner
        $this._ChildName = $ChildName
        $this._Path = $null
    }

    hidden [PSCustomObject] readCurrentNode([bool] $avoidReload) {
        if ([string]::IsNullOrWhiteSpace($this._Path)) {
            return $this._Owner.readChildNode($this._ChildName,$avoidReload)
        }

        if (-not (Test-Path $this._Path -PathType Leaf)) {
            if ($this._CachedModel -eq $null)
            {
                $this._CachedModel = $this.getNewNode()
            }
        }
        else {
            if (-not $avoidReload -or $this._CachedModel -eq $null) {
                $this._CachedModel = Get-Content -Raw $this._Path | ConvertFrom-Json
            }
        }

        return $this._CachedModel
    }
    hidden [PSCustomObject] readChildNode([string] $ChildName, [bool] $avoidReload) {

        $node = $this.readCurrentNode($avoidReload)
        $member = $node `
            | Get-Member -Type NoteProperty `
            | Where-Object { [string]::Equals($_.Name, "$ChildName".Trim(), "InvariantCultureIgnoreCase") } `
            | Select-Object -First 1 -ExpandProperty $_.Name

        if ($member -eq $null) {
            $node | Add-Member -Type NoteProperty -Name $ChildName -Value ($this.getNewNode())
            if (-not $avoidReload) {
                $this.saveRootNode();
                $node = $this.getObject()
            }
        }

        return $node."$ChildName"
    }
    
    hidden [PSCustomObject] getNewNode() {
        return [PSCustomObject] @{ }
    }
    hidden [object] getChildOrValue([object] $Node, [string] $Property) {

        if ($Node -eq $null) {
            $Node = $this.getNewNode()
        }

        $member = $Node `
            | Get-Member -Type NoteProperty `
            | Where-Object { [string]::Equals($_.Name, "$Property".Trim(), "InvariantCultureIgnoreCase") } `
            | Select-Object -First 1 -ExpandProperty $_.Name

        if ($member -eq $null) {
            return $null
        }

        return $Node | Select-Object -ExpandProperty $member.Name
    }
    hidden [void] saveRootNode() {

        if ($this._Owner -ne $null) {
            $this._Owner.saveRootNode()
        }
        else {
            $this.readCurrentNode($true) | ConvertTo-Json -Depth 100 | Set-Content $this._Path
        }
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