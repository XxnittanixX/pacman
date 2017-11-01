Move-Item `
    -Path        (join-path $_.Directory.FullName "project.csproj") `
    -Destination (join-path $_.Directory.FullName "$($_.Directory.Name).csproj") 

$properties = New-PropertyContainer (Join-Path $_.Directory.FullName "package.json")
$properties.setProperty("pacman", @{
    "build" = @{
        "projects" = "*.csproj"
        "target" = "Restore,Pack"
        "parameters" = @{
            "configuration" = "Release"
            "platform" = "Any CPU"
        }
    }
})