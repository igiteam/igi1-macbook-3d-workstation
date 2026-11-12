# download-igi-repos.ps1
# Downloads each igiteam repo as a ZIP so you can re-upload them elsewhere.

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

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "Downloading $($repos.Count) repos to $outDir" -ForegroundColor Cyan

$results = @()

foreach ($repo in $repos) {
    $downloaded = $false

    foreach ($branch in $branches) {
        $url  = "https://github.com/$owner/$repo/archive/refs/heads/$branch.zip"
        $dest = Join-Path $outDir "$repo-$branch.zip"

        try {
            Write-Host "  -> $repo ($branch)" -ForegroundColor Yellow
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop

            # Sanity check: GitHub returns a tiny HTML error page on 404, not a zip
            $size = (Get-Item $dest).Length
            if ($size -lt 1024) {
                throw "File too small ($size bytes) — likely a 404 page"
            }

            Write-Host "     OK ($([math]::Round($size/1KB)) KB)" -ForegroundColor Green
            $results += [pscustomobject]@{ Repo = $repo; Branch = $branch; Status = "OK"; SizeKB = [math]::Round($size/1KB) }
            $downloaded = $true
            break
        }
        catch {
            if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
            Write-Host "     failed on '$branch': $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }

    if (-not $downloaded) {
        Write-Host "     !! could not download $repo on main or master" -ForegroundColor Red
        $results += [pscustomobject]@{ Repo = $repo; Branch = "-"; Status = "FAILED"; SizeKB = 0 }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$results | Export-Csv -Path (Join-Path $outDir "_download-report.csv") -NoTypeInformation
Write-Host "Report written to $outDir\_download-report.csv" -ForegroundColor Cyan
