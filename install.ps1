# Installs MoltZip on Windows from the latest release, or updates it.
#
#   irm https://raw.githubusercontent.com/morningstar-code/moltzip/main/install.ps1 | iex
#
# It downloads the Windows build, checks it against the published checksum,
# puts it in %LOCALAPPDATA%\Programs\MoltZip and adds that folder to your
# PATH. No administrator rights needed.
#
# To remove it again:
#
#   $env:MOLTZIP_UNINSTALL = 1; irm https://raw.githubusercontent.com/morningstar-code/moltzip/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Repo = 'morningstar-code/moltzip'
$Dir = Join-Path $env:LOCALAPPDATA 'Programs\MoltZip'

function Get-UserPath {
    [Environment]::GetEnvironmentVariable('Path', 'User') -split ';' | Where-Object { $_ }
}

if ($env:MOLTZIP_UNINSTALL) {
    Remove-Item Env:\MOLTZIP_UNINSTALL
    Write-Host 'Removing MoltZip' -ForegroundColor White
    Remove-Item -Recurse -Force $Dir -ErrorAction SilentlyContinue
    $kept = Get-UserPath | Where-Object { $_ -ne $Dir }
    [Environment]::SetEnvironmentVariable('Path', ($kept -join ';'), 'User')
    Write-Host 'Removed. Half-finished extractions keep their .moltzip files next to the archive.'
    return
}

$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -ne 'AMD64' -and $arch -ne 'ARM64') {
    throw "MoltZip needs 64-bit Windows, this is $arch."
}
# ARM64 Windows runs the x64 build through its built-in emulation.
$name = 'moltzip-x86_64-windows'
$base = "https://github.com/$Repo/releases/latest/download"
if ($env:MOLTZIP_VERSION) {
    $base = "https://github.com/$Repo/releases/download/$env:MOLTZIP_VERSION"
}
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("moltzip-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
    Write-Host 'Downloading MoltZip for Windows' -ForegroundColor White
    $zip = Join-Path $tmp "$name.zip"
    $sum = Join-Path $tmp "$name.zip.sha256"
    Invoke-WebRequest -UseBasicParsing -Uri "$base/$name.zip" -OutFile $zip
    # Saved to a file and read back as text: GitHub serves it as binary, so
    # reading the response directly gives bytes, not the hash.
    Invoke-WebRequest -UseBasicParsing -Uri "$base/$name.zip.sha256" -OutFile $sum
    $expected = ((Get-Content -Raw $sum).Trim() -split '\s+')[0]
    $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash
    if ($actual -ne $expected.ToUpper()) {
        throw 'The download does not match its checksum, nothing was installed.'
    }

    Write-Host "Installing to $Dir" -ForegroundColor White
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    Expand-Archive -Force -Path $zip -DestinationPath $Dir
    Get-ChildItem $Dir | Unblock-File

    if ((Get-UserPath) -notcontains $Dir) {
        $paths = @(Get-UserPath) + $Dir
        [Environment]::SetEnvironmentVariable('Path', ($paths -join ';'), 'User')
        $env:Path = "$env:Path;$Dir"
        Write-Host "Added $Dir to your PATH. New terminals pick it up automatically."
    }

    # `mz` is the short name, unless some other program already answers to it.
    $otherMz = Get-Command mz -ErrorAction SilentlyContinue | Where-Object { $_.Source -ne (Join-Path $Dir 'mz.exe') }
    if ($otherMz) {
        Write-Host "Skipping the short name mz: $($otherMz.Source) already uses it."
    } else {
        Copy-Item -Force (Join-Path $Dir 'moltzip.exe') (Join-Path $Dir 'mz.exe')
    }

    $version = & (Join-Path $Dir 'moltzip.exe') --version
    Write-Host ''
    Write-Host "$version installed." -ForegroundColor Green
    Write-Host 'Try: moltzip check some-archive.zip (or the short name: mz check some-archive.zip)'
    Write-Host "Tab completion: add '. $Dir\moltzip-completion.ps1' to your `$PROFILE."
} finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
