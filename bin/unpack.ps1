param(
    [PSDefaultValue(Help='Search filter')]
    [string]$PackagePattern = "*.PAK",

    [PSDefaultValue(Help='Folder containing PAK files')]
    [string]$GameRootData = $(Join-Path $(Get-Location) ".." | Join-Path -ChildPath "Data")
)

$gust_pak = Join-Path $PSScriptRoot "gust_tools/gust_pak.exe"
$gust_g1t = Join-Path $PSScriptRoot "gust_tools/gust_g1t.exe"

Get-ChildItem -path $GameRootData -Recurse -Filter "$PackagePattern" | ForEach-Object {
    $packageDir = Join-Path $GameRootData $_.BaseName
    $packageTarget = Join-Path $packageDir $_
    $packageTargetJson = $(Join-Path $packageDir $_.BaseName) + ".json"


    If (!(Test-Path -PathType container $packageDir))
    {
        New-Item -ItemType Directory -Path $packageDir | Out-Null
    }

    If (!(Test-Path $packageTarget -PathType Leaf))
    {
        & cmd /c mklink "$packageTarget" "..\$($_)" | Out-Null
    }

    If (!(Test-Path $packageTargetJson -PathType Leaf))
    {
        & "$gust_pak" "$packageTarget" 
    }

    Get-ChildItem -path $packageDir -Recurse -Filter "*.g1t" | ForEach-Object {
        & "$gust_g1t" "-y" $($_.FullName)
    }
}
