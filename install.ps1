# Install with: irm https://raw.githubusercontent.com/capibaras001/wycode/main/install.ps1 | iex
& {
    $ErrorActionPreference = 'Stop'
    if ($env:OS -ne 'Windows_NT') {
        throw 'Use install.sh on Linux or macOS. This installer is for Windows.'
    }
    $architecture = $env:PROCESSOR_ARCHITEW6432
    if (-not $architecture) { $architecture = $env:PROCESSOR_ARCHITECTURE }
    $arch = switch -Regex ($architecture) {
        '^(AMD64|x86_64|x86-64|x64)$' { 'amd64'; break }
        '^(ARM64|aarch64)$' { 'arm64'; break }
        default { throw "Unsupported architecture: $architecture" }
    }
    $version = $env:WYCODE_VERSION
    if (-not $version) { $version = 'latest' }
    $release = 'latest/download'
    if ($version -ne 'latest') {
        if ($version -notmatch '^v?[0-9]+\.[0-9]+\.[0-9]+([-+][A-Za-z0-9.-]+)?$') {
            throw "Invalid WYCODE_VERSION: $version"
        }
        $release = 'download/v' + $version.TrimStart('v')
    }
    $base = $env:WYCODE_RELEASE_BASE_URL
    if (-not $base) { $base = 'https://github.com/capibaras001/wycode/releases' }
    $asset = "wycode-windows-$arch.zip"
    $installDir = $env:WYCODE_INSTALL_DIR
    if (-not $installDir) { $installDir = Join-Path $env:USERPROFILE '.local\bin' }
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('wycode-install-' + [Guid]::NewGuid())
    $staged = $null
    New-Item -ItemType Directory -Path $temporary | Out-Null
    try {
        # Windows PowerShell 5.1 needs TLS 1.2 for GitHub downloads.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Write-Host "Downloading $asset ($version)..."
        $archive = Join-Path $temporary $asset
        Invoke-WebRequest -UseBasicParsing -Uri "$($base.TrimEnd('/'))/$release/$asset" -OutFile $archive
        $sums = Join-Path $temporary 'SHA256SUMS'
        Invoke-WebRequest -UseBasicParsing -Uri "$($base.TrimEnd('/'))/$release/SHA256SUMS" -OutFile $sums
        $entries = @(Get-Content -LiteralPath $sums | Where-Object { $_ -match ('^[a-fA-F0-9]{64}\s+\*?' + [Regex]::Escape($asset) + '$') })
        if ($entries.Count -ne 1 -or ($entries[0] -split '\s+')[0] -ne (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash) {
            throw "SHA256 verification failed for $asset; existing installation was preserved."
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($archive)
        try {
            $names = @('wycode.exe', 'LICENSE', 'APACHE-2.0', 'NOTICE', 'README.md')
            if ($zip.Entries.Count -ne $names.Count) {
                throw 'Unexpected archive contents; existing installation was preserved.'
            }
            foreach ($entry in $zip.Entries) {
                $type = ($entry.ExternalAttributes -shr 16) -band 61440
                if ($names -cnotcontains $entry.FullName -or ($type -ne 0 -and $type -ne 32768)) {
                    throw 'Unexpected archive contents; expected regular release files. Existing installation was preserved.'
                }
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $temporary $entry.FullName))
            }
            foreach ($name in $names) {
                if (-not (Test-Path -LiteralPath (Join-Path $temporary $name) -PathType Leaf)) {
                    throw "Archive is missing $name."
                }
            }
        }
        finally { $zip.Dispose() }
        $installed = Join-Path $installDir 'wycode.exe'
        if (Test-Path -LiteralPath $installed -PathType Leaf) {
            Write-Host 'Stopping the existing wycode background service before upgrading...'
            & $installed service stop
            if ($LASTEXITCODE -ne 0) {
                throw 'The existing wycode service could not stop. Close all wycode sessions, run wycode service stop, then retry. The installed executable was preserved.'
            }
        }
        New-Item -ItemType Directory -Force -Path $installDir | Out-Null
        $documents = Join-Path $installDir 'wycode-docs'
        New-Item -ItemType Directory -Force -Path $documents | Out-Null
        foreach ($name in @('LICENSE', 'APACHE-2.0', 'NOTICE', 'README.md')) {
            Copy-Item -LiteralPath (Join-Path $temporary $name) -Destination (Join-Path $documents $name) -Force
        }
        $staged = Join-Path $installDir ('.wycode-' + [Guid]::NewGuid() + '.exe')
        Copy-Item -LiteralPath (Join-Path $temporary 'wycode.exe') -Destination $staged
        try { Move-Item -LiteralPath $staged -Destination $installed -Force }
        catch { throw "Could not replace wycode.exe. Close all wycode TUI sessions and retry the installer. $($_.Exception.Message)" }
        $staged = $null
        Write-Host "Installed wycode to $installDir\wycode.exe"
        if (($env:PATH -split ';') -notcontains $installDir) {
            Write-Host 'Add this directory to your user PATH in Environment Variables, then open a new terminal:'
            Write-Host "  $installDir"
            Write-Host 'For this PowerShell session, run:'
            Write-Host ('$env:PATH = ' + "'" + $installDir.Replace("'", "''") + ";' + " + '$env:PATH')
        }
        Write-Host 'Run: wycode --version'
    }
    finally {
        Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
        if ($staged) { Remove-Item -LiteralPath $staged -Force -ErrorAction SilentlyContinue }
    }
}
