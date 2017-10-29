mv `
    (join-path $_.Directory.FullName "project.csproj") `
    (join-path $_.Directory.FullName "$($_.Directory.Name).csproj") 