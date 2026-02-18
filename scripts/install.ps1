[CmdletBinding()]
param(
  [string]$Version = $env:KR_VERSION,
  [string]$InstallDir = $env:KR_INSTALL_DIR,
  [string]$Repo = $(if ($env:KR_REPO) { $env:KR_REPO } else { "rcastellotti/kr" })
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$BinName = "kr"

function Resolve-Tag {
  param(
    [string]$RepoName,
    [string]$RequestedVersion
  )

  if ($RequestedVersion) {
    if ($RequestedVersion.StartsWith("v")) {
      return $RequestedVersion
    }
    return "v$RequestedVersion"
  }

  $headers = @{
    Accept = "application/vnd.github+json"
    "User-Agent" = "kr-install-script"
  }
  $latest = Invoke-RestMethod -Uri "https://api.github.com/repos/$RepoName/releases/latest" -Headers $headers
  if (-not $latest.tag_name) {
    throw "Could not resolve latest release tag for $RepoName"
  }
  return [string]$latest.tag_name
}

function Resolve-Arch {
  $architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
  switch ($architecture) {
    "X64" { return "amd64" }
    "Arm64" { return "arm64" }
    default { throw "Unsupported architecture: $architecture" }
  }
}

if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
  throw "tar is required to extract release archives."
}

if (-not $InstallDir) {
  $InstallDir = Join-Path $HOME "bin"
}

$tag = Resolve-Tag -RepoName $Repo -RequestedVersion $Version
$versionNoV = $tag.TrimStart("v")
$arch = Resolve-Arch
$archiveName = "${BinName}_${versionNoV}_windows_${arch}.tar.gz"
$downloadUrl = "https://github.com/$Repo/releases/download/$tag/$archiveName"

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("kr-install-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
  $archivePath = Join-Path $tempDir $archiveName
  Write-Host "Downloading $downloadUrl"
  Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath

  tar -xzf $archivePath -C $tempDir
  $source = Join-Path $tempDir "$BinName.exe"
  if (-not (Test-Path $source)) {
    throw "$BinName.exe not found in archive $archiveName"
  }

  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  $destination = Join-Path $InstallDir "$BinName.exe"
  Copy-Item -Path $source -Destination $destination -Force
  Write-Host "Installed $BinName to $destination"

  $pathEntries = $env:Path -split ";"
  if (-not ($pathEntries -contains $InstallDir)) {
    Write-Warning "$InstallDir is not currently on PATH."
    Write-Host "Add it with:"
    Write-Host "[Environment]::SetEnvironmentVariable('Path', `$env:Path + ';$InstallDir', 'User')"
  }
}
finally {
  if (Test-Path $tempDir) {
    Remove-Item -Path $tempDir -Recurse -Force
  }
}
