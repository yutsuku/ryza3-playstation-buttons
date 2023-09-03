$gust_pak = "./bin/gust_tools/gust_pak.exe"
$gust_g1t = "./bin/gust_tools/gust_g1t.exe"
$tempRoot = "temp"

function Read-KeyOrTimeout ($prompt, $key)
{
    $seconds = 9
    $startTime = Get-Date
    $timeOut = New-TimeSpan -Seconds $seconds

    Write-Host "$prompt " -ForegroundColor Yellow

    # Basic progress bar
    [Console]::CursorLeft = 0
    [Console]::Write("[")
    [Console]::CursorLeft = $seconds + 2
    [Console]::Write("]")
    [Console]::CursorLeft = 1

    while (-not [System.Console]::KeyAvailable) {
        $currentTime = Get-Date
        Start-Sleep -s 1
        Write-Host "#" -ForegroundColor Yellow -NoNewline
        if ($currentTime -gt $startTime + $timeOut) {
            [Console]::CursorLeft = [Console]::CursorLeft + 2
            Break
        }
    }
    if ([System.Console]::KeyAvailable) {
        $response = [System.Console]::ReadKey($true).Key
    }
    else {
        $response = $key
    }
    return $response.ToString()
}

function Get-Hash()
{
    # 1.05
    $values = @{
        1.05 = @{
            executable = @{
                path = "\Atelier_Ryza_3.exe"
                hash = "23F18866795A1F1C1106AFEB6D303D7B2D0DE4292AA8CEAE4CFC8217AC8D3A70"
            }
            PACK05_02 = @{
                path = "\Data\PACK05_02.PAK"
                hash = "A8974E5A17EE246479566726569D9FD285827DEC06AEBE2D8759A5AE1F5043C1"
            }
        }
    }

    foreach ($version in $values.GetEnumerator()) {
        $misses = 0

        foreach ($package in $version.Value.GetEnumerator()) {
            Write-Host ($package.Value.path) -NoNewline
            [Console]::CursorLeft = [Console]::CursorLeft + 1

            $filePath = $(Join-Path $(Get-Location) -ChildPath ".." | Join-Path -ChildPath $package.Value.path)
            $fileHash = Get-FileHash -Algorithm SHA256 -Path "$filePath" | Select-Object -ExpandProperty Hash

            if ($fileHash -ieq $package.Value.hash) {
                Write-Host "OK" -ForegroundColor Green
            } else {
                Write-Host "Mismatch" -ForegroundColor Yellow
                $misses++
            }
        }

        if (!$misses) {
            Write-Host "Will patch game against `"$($version.Name)`"" -ForegroundColor Green
            return $false
        }
    }

    return $true
}

function Prepare()
{
    If (!(Test-Path -PathType container $tempRoot))
    {
        New-Item -ItemType Directory -Path $tempRoot | Out-Null
    }
}

function Cleanup()
{
    If (Test-Path $tempRoot -PathType Container)
    {
        Start-Sleep -Milliseconds 1000
        Remove-Item -Path "$tempRoot" -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Patch()
{
    (Get-ChildItem -Path $tempRoot -File -Recurse -Filter "*.PAK") | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $(Join-Path $(Get-Location) -ChildPath ".." | Join-Path -ChildPath "Data") -Force
    }
}

<#
.Description
Process patch

prepare directories,
make symbolic link for gust_tools since it doesn't support output path.
copy patch content
find raw texture directories, patch them up
create new PAK
#>
function New-Pak-Dds {
    param (
        [Parameter(Mandatory)]
        [string]$package,

        [PSDefaultValue(Help='package variant if there is more than one')]
        [string]$variant = ""
    )

    $packageRoot = "$tempRoot\$package"
    $packagArchive = "$tempRoot\$package\$package.PAK"
    $packagJson = "$tempRoot\$package\$package.json"

    If (!(Test-Path -PathType container $packageRoot))
    {
        New-Item -ItemType Directory -Path $packageRoot | Out-Null
    }


    If (!(Test-Path $packagArchive -PathType Leaf))
    {
        & cmd /c mklink "$packagArchive" "..\..\..\Data\$package.PAK" | Out-Null
    }

    If (!(Test-Path $packagJson -PathType Leaf))
    {
        Write-Host "Extracting `"$packagArchive`"" -ForegroundColor Green
        & "$gust_pak" "$(Join-Path $(Get-Location) $packagArchive)" | Out-Null
    }

    $source = "src\$package" + $variant
    $destination = "temp\$package"

    # unpack only necessary files
    (Get-ChildItem -Path $source -File -Recurse -Filter "*.dds") | Select-Object -ExpandProperty DirectoryName -Unique | ForEach-Object {
        $textureFileArchive = "$_".Replace($source, $destination) + ".g1t"

        If (Test-Path $textureFileArchive -PathType Leaf)
        {
            Write-Host "Extracting `"$textureFileArchive`"" -ForegroundColor Green
            & "$gust_g1t" "$textureFileArchive"
            Remove-Item -Path "$textureFileArchive" -Force
        }
    }

    # overwrite with new files
    Write-Host "Copying patch files from `"$source`" to `"$destination`"" -ForegroundColor Green
    Copy-Item -Path $($source + "\*") -Destination $destination -Recurse -force

    # pack it back
    (Get-ChildItem -Path $destination -File -Recurse -Filter "*.dds") | Select-Object -ExpandProperty DirectoryName -Unique | ForEach-Object {
        Write-Host "Packing up `"$_`"" -ForegroundColor Green
        & "$gust_g1t" "$_"
    }

    Write-Host "Packing up `"$packagJson`"" -ForegroundColor Green
    & "$gust_pak" "$(Join-Path $(Get-Location) $packagJson)" | Out-Null
}

#
# Main script entry point
#
try {
    
    if (Get-Hash) {
        $result = Read-KeyOrTimeout "The patch was not tested with your game version. Continue installation? [Y/n] (default=n)" "N"
        if ($result -eq 'N') {
            throw "Game version mismatch."
        }
    }

    $variant = ""
    $result = Read-KeyOrTimeout "Use classic SELECT/PLAY buttons? [Y/n] (default=n)" "N"

    if ($result -eq 'N') {

    } else {
        $variant = "_classic"
    }

    Prepare
    New-Pak-Dds -package "PACK05_02" -variant "$variant"
    Install-Patch
    Cleanup

    Write-Host "Operation completed" -ForegroundColor Magenta
}
catch [System.Exception] {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
