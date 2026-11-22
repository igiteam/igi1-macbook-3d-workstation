
#!/bin/bash

SCRIPT="$HOME/igi-download.sh"

cat > "$SCRIPT" <<'SCRIPT_EOF'
#!/bin/bash

DEST="$HOME/Downloads/IGI-Team-Projects"

mkdir -p "$DEST"
cd "$DEST" || exit 1

PROJECTS=(
    # MAIN PROJECTS (40)
    openofpcwc-projectigi
    postal2-half-dude-the-thing
    dfbhdts-projectigi-2
    thief-gold-prince-of-persia-3d
    hl2-wolfschanze1944
    fear-dmmm-nosferatu-wrath-of-malachi
    007-goldeneye-tomorrow-never-dies
    openmohaa-medal-of-honor-psx
    openjkdf2-star-wars-episode-i-ii-iii
    lego-racers-island-2-spyrius
    mohpa-vietnam
    red-faction-red-faction-2
    opentobey-spiderman-trilogy
    enter-the-matrix-blade-trilogy
    halo-ce-123
    virtua-cop-2-tokyo-zombie
    cod3_hd
    arx-fatalis-vampire-the-masquerade-redemption
    indiana-jones-emperors-tomb-infernal-machine
    iortcw-mortyr-1944
    openofpcwc-hidden-and-dangerous
    die-hard-nakatomi-plaza-die-hard-trilogy
    oni-the-fifth-element
    halo-ce-duke-nukem-3d
    terminator-war-of-the-machines-future-shock
    serious-sam-first-encounter-starship-troopers
    duke-nukem-forever-2001
    midtown-madness-3-redriver-driv3r
    stalker-oblivion-lost
    hitman-codename-47-mission-impossible-psx
    max-payne-2001
    bloodrayne-underworld-trilogy
    far-cry-2004
    cod2-hour-of-victory
    alien-vs-predator-classic-alien-resurrection
    tactical-intervention-rainbow-six-1998
    doom3-e3-alpha-rtcw
    transformers-takara-transformers-the-movie-1986
    far-cry-2004-aliens-vs-predator-2
    cod2003-brothers-in-arms

    # IN PROGRESS (2)
    openlara-the-mummy
    colin-mcrae-rally-2-mobile-rally-championship-psx

    # MISSING PROJECTS (10)
    bloodrayne-spawn-the-eternal
    call-of-juarez-bound-in-blood-gun-warrior
    r6-vegas-kill-switch
    r6-vegas-ghost-recon-2001
    gta-iii-they-live
    fear-history-channel-battle-for-pacific
    deadly-dozen-2001
    elite-forces-ww2
    marines-modern-urban-combat-wii
    medal-of-honor-vanguard-wii
)

TOTAL=${#PROJECTS[@]}
COUNT=0
SUCCESS=0
FAILED=0
SKIPPED=0

echo "=========================================="
echo " IGI TEAM - PROJECT DOWNLOADER"
echo "=========================================="
echo "Projects: $TOTAL"
echo "Destination: $DEST"
echo "=========================================="

for REPO in "${PROJECTS[@]}"; do
    COUNT=$((COUNT + 1))
    ZIP="${REPO}.zip"
    URL="https://github.com/igiteam/${REPO}/archive/HEAD.zip"

    echo
    echo "[$COUNT/$TOTAL] $REPO"

    if [ -s "$ZIP" ]; then
        echo "SKIPPED: Already downloaded"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if curl -fL --retry 2 --retry-delay 2 \
        --progress-bar \
        -o "$ZIP" \
        "$URL"; then

        echo "SUCCESS: $ZIP"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "FAILED: $REPO"
        rm -f "$ZIP"
        FAILED=$((FAILED + 1))
    fi
done

echo
echo "=========================================="
echo " DOWNLOAD COMPLETE"
echo "=========================================="
echo "Total projects: $TOTAL"
echo "Downloaded: $SUCCESS"
echo "Already existed: $SKIPPED"
echo "Failed: $FAILED"
echo "Saved in: $DEST"
echo "=========================================="
SCRIPT_EOF

chmod +x "$SCRIPT"

echo "Script created and made executable."
echo "Starting downloads..."
echo

"$SCRIPT"
