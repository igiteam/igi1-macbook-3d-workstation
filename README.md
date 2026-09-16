# igi1-macbook-3d-workstation
Read Macbooks.txt

# 1. Install requests
pip3 install requests

# 2. Get your eBay API keys
#    → https://developer.ebay.com/my/keys
#    → Create an app, grab App ID (Client ID) + Cert ID (Client Secret)

# 2.1 create .env file
EBAY_CLIENT_ID=""
EBAY_CLIENT_SECRET=""

# 3. Export them
export EBAY_CLIENT_ID="YourApp-YourApp-PRD-xxxxxxxxx-xxxxxxxx"
export EBAY_CLIENT_SECRET="PRD-xxxxxxxxxxxx-xxxx-xxxx-xxxx-xxxx"

# 4. Run it (make sure ebay-items.json is in the same folder)
python3 ebay_search.py

📦 Loaded 14 items from ebay-items.json

🔑 Getting eBay access token...
✅ Token acquired

======================================================================
[1/14] MacBook Pro 16" 2019 i9 8-Core 2.4Ghz 32GB Ram 1TB SSD AMD 5500M 8GB Space Grey
======================================================================
   GBP 474.99   https://www.ebay.co.uk/itm/1234567890
   GBP 499.00   https://www.ebay.co.uk/itm/2345678901
   GBP 525.00   https://www.ebay.co.uk/itm/3456789012
   GBP 549.99   https://www.ebay.co.uk/itm/4567890123
   GBP 579.00   https://www.ebay.co.uk/itm/5678901234

======================================================================
[2/14] MacBook Pro 16" 2019 i9-9880H 2.3 Ghz 1TB SSD 32GB RAM A2141 AMD 5500M 4GB Space Grey
======================================================================
   GBP 349.99   https://www.ebay.co.uk/itm/6789012345
   ...


🔑 What You Need to Know
Thing	                Where
eBay Developer Account	developer.ebay.com
App ID (Client ID)	    "Application Keys" → "App ID"
Cert ID (Client Secret)	"Application Keys" → "Cert ID"

Marketplace	EBAY-GB for UK, EBAY-US for US
Rate limit	5 calls/sec default — the script sleeps 0.5s between items

┌─────────────────────────────────────────────────────────────────────────┐
│                    WHY THIS SETUP EXISTS                                │
│                    3D DEVELOPMENT STUDIO                                │
└─────────────────────────────────────────────────────────────────────────┘
Remake classic PC games — faithfully and fast — across multiple engines.

Not ports. Not remasters with new assets. Recreations that run the original gameplay,
original maps, original feel — rebuilt on modern engines so they can be extended,
modded, and preserved.

Target list (so far):

    Project IGI → Operation Flashpoint

    The Thing → RTCW / Doom 3

    Wolfschanze 1944 → Half-Life 2

    Nosferatu: Wrath of Malachi → F.E.A.R. / Dark Messiah

    ...and more

Why Three Macs

Because game remaking is not one job. It's three jobs happening at once:
text

  MAC 1 (Canvas)      →  You BUILD the game
  MAC 2 (Reference)   →  You LOOK at the original
  MAC 3 (Testing)     →  You PLAY the result

If you try to do all three on one machine, you spend half your day:

    Alt-tabbing between windows

    Losing your editor state

    Reloading the reference every time you test

    Fighting Wine + editor + game + tools on one CPU

Three Macs = three jobs = zero context switching.
Why Three macOS Versions

Each macOS version has a reason:
  Monterey 12.4   →  Best balance for OFP Mission Editor + dev tools, compilation
  Sonoma 14.5     →  Modern tooling, VSCode, Xcode, Swift, browsers, ORIGINAL GAME, compilation
  Big Sur 11.7    →  Runs the test game + Wine configs + wiimote (bluetooth 2.1 compatibility)

Some legacy games only run on older macOS. Some dev tools only run on newer.
By having all three, you never hit "this doesn't work on my OS."
Why the VT30 3D Plasma

Operation Flashpoint and other games in the list were meant to be immersive.
A 55" 3D plasma output means:
    Full-screen 3D preview of what you're building
    Anaglyph testing on real hardware, not a small laptop screen
    Shared display for all three Macs (HDMI 1, 2, 3) — no KVM needed
    The room IS the dev environment — walk from desk to TV, keep working

Why the Wii Remotes + IR Sensor Bars

Traditional dev = mouse + keyboard. But you're recreating games that had:
    Motion controls
    Point-and-shoot aiming
    Gesture-based interaction

You can't test those with a mouse. The Wiimote + nunchuck lets you:
    Play-test the exact input the game was designed for
    Record motion for animation reference
    Feel the game the way players will

Two IR bars = seamless desk ↔ TV workflow:
    At the desk → point Wiimote at Mac's IR bar → keep developing
    Walk to the TV → point Wiimote at TV's IR bar → play-test full screen
    Same Wiimote, same game, same state. Just move your feet.

Why Logitech Flow

One mouse. One keyboard. Three Macs.

The custom app (igiteam/logitec_mx_mouse_3_macos) bridges the gap that Logitech
Options+ refused to bridge across Big Sur / Monterey / Sonoma.

Result: one input device for the whole studio. No KVM, no extra peripherals,
no copy-paste between machines by hand.
Why eBay Tracking Matters

This entire setup was sourced from eBay over ~3 weeks.
Total cost: £1,302.35 for a studio that would cost 4–5x that new.

Tracking it means:
    When a part fails, you know the exact model + fair price
    When you onboard someone, you can quote a real number
    When prices drop, you know it's time to buy spares
    The setup becomes replicable, not just documented

The Deeper Why

Every game remake that ships from this studio proves the model works:
    Speed: multiple titles per year, not per decade
    Fidelity: original feel, not "reimagined"
    Scalability: hand a new team member this doc → they're productive in days
    Preservation: games from 2000–2010 that would otherwise be lost

The point isn't the hardware. The point is that this hardware removes every excuse
not to ship. No "I can't test 3D". No "I can't run the original". No "my Mac can't
handle both the editor and the game at once."

Every friction point has a dedicated machine, a dedicated OS, a dedicated screen.