# download-igi-repos.ps1
# Downloads each igiteam repo as a ZIP so you can re-upload them elsewhere.
# Verifies each download is a real, non-empty ZIP before accepting it.

# --- config ---------------------------------------------------------------
$repos = @(
    "igi1-macbook-3d-workstation",
    "postal2-half-dude-the-thing",
    "virtua-cop-2-tokyo-zombie",
    "halo-ce-123",
    "cod3_hd",
    "thief-gold-prince-of-persia-3d",
    "openmohaa-medal-of-honor-psx",
    "007-goldeneye-tomorrow-never-dies",
    "openofpcwc-projectigi",
    "opentobey-spiderman-trilogy",
    "enter-the-matrix-blade-trilogy",
    "red-faction-red-faction-2",
    "mohpa-vietnam",
    "openjkdf2-star-wars-episode-i-ii-iii",
    "lego-racers-island-2-spyrius",
    "indiana-jones-emperors-tomb-infernal-machine",
    "colin-mcrae-rally-2-mobile-rally-championship-psx",
    "hl2-wolfschanze1944",
    "fear-dmmm-nosferatu-wrath-of-malachi",
    "logitec_mx_mouse_3_macos",
    "alien-vs-predator-classic-alien-resurrection",
    "hitman-codename-47-mission-impossible-psx",
    "webassembly_games"
)

$owner    = "igiteam"
$outDir   = Join-Path (Get-Location) "downloads"
$branches = @("main", "master")

# --- setup ----------------------------------------------------------------
# GitHub requires TLS 1.2; Windows PowerShell 5.1 may default to TLS 1.0.
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

# Needed for Test-IsRealZip
Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

# --- helper: is this file actually a non-empty ZIP? -----------------------
function Test-IsRealZip {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$MinEntries = 1
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $false }

    # 1) magic bytes: PK\x03\x04 (regular), PK\x05\x06 (empty), PK\x07\x08 (spanned)
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        try {
            $sig  = New-Object byte[] 4
            $read = $fs.Read($sig, 0, 4)
        } finally {
            $fs.Dispose()
        }
    } catch {
        return $false
    }

    if ($read -lt 4) { return $false }

    $isPk = ($sig[0] -eq 0x50 -and $sig[1] -eq 0x4B -and
             (($sig[2] -eq 0x03 -and $sig[3] -eq 0x04) -or
              ($sig[2] -eq 0x05 -and $sig[3] -eq 0x06) -or
              ($sig[2] -eq 0x07 -and $sig[3] -eq 0x08)))
    if (-not $isPk) { return $false }

    # 2) can it actually be opened as a ZIP with at least $MinEntries entries?
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
        try {
            return ($zip.Entries.Count -ge $MinEntries)
        } finally {
            $zip.Dispose()
        }
    } catch {
        return $false
    }
}

# --- download loop --------------------------------------------------------
Write-Host "Downloading $($repos.Count) repos to $outDir" -ForegroundColor Cyan

$results = @()

foreach ($repo in $repos) {
    $downloaded = $false

    foreach ($branch in $branches) {
        $url  = "https://github.com/$owner/$repo/archive/refs/heads/$branch.zip"
        $dest = Join-Path $outDir "$repo-$branch.zip"
        $tmp  = "$dest.part"

        # clean slate for this attempt
        Remove-Item -LiteralPath $dest, $tmp -Force -ErrorAction SilentlyContinue

        try {
            Write-Host "  -> $repo ($branch)" -ForegroundColor Yellow

            $resp = Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing `
                                      -TimeoutSec 120 -ErrorAction Stop `
                                      -PassThru

            # 1) explicit status check — only 200 counts as success
            $status = [int]$resp.StatusCode
            if ($status -ne 200) {
                throw "HTTP $status (not 200)"
            }

            # 2) content-type check — GitHub serves ZIPs as application/zip
            $ct = $resp.Headers['Content-Type']
            if ($ct -and ($ct -notmatch 'zip|octet-stream')) {
                throw "Content-Type '$ct' is not a zip"
            }

            # 3) authoritative check — is it really a non-empty ZIP?
            if (-not (Test-IsRealZip -Path $tmp -MinEntries 1)) {
                throw "Downloaded file is not a valid non-empty ZIP"
            }

            # promote the verified temp file to its real name
            Move-Item -LiteralPath $tmp -Destination $dest -Force

            $size = (Get-Item -LiteralPath $dest).Length
            Write-Host "     OK ($([math]::Round($size/1KB)) KB)" -ForegroundColor Green

            $results += [pscustomobject]@{
                Repo   = $repo
                Branch = $branch
                Status = "OK"
                SizeKB = [math]::Round($size/1KB)
            }
            $downloaded = $true
            break
        }
        catch {
            Write-Host "     failed on '$branch': $($_.Exception.Message)" -ForegroundColor DarkGray
            Remove-Item -LiteralPath $dest, $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not $downloaded) {
        Write-Host "     !! could not download $repo on main or master" -ForegroundColor Red
        $results += [pscustomobject]@{
            Repo   = $repo
            Branch = "-"
            Status = "FAILED"
            SizeKB = 0
        }
    }
}

# --- summary + report -----------------------------------------------------
Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$reportPath = Join-Path $outDir "_download-report.csv"
$results | Export-Csv -Path $reportPath -NoTypeInformation
Write-Host "Report written to $reportPath" -ForegroundColor Cyan

# exit non-zero if anything failed, so the caller can detect it
$failed = @($results | Where-Object { $_.Status -ne "OK" }).Count
if ($failed -gt 0) {
    Write-Host "$failed repo(s) failed to download." -ForegroundColor Red
    exit 1
}
Write-Host "All repos downloaded and verified." -ForegroundColor Green
exit 0
