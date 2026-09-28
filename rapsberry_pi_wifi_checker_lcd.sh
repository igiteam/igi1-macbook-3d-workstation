#!/bin/bash
# ============================================================
# Raspberry Pi Portable Wi-Fi LCD Configurator - INSTALLER
# ============================================================
# This is a standalone boot-time Wi-Fi configurator for your
# portable Pi.
#rapsberry-pi-5-portable-forgejogitlf-ubuntu.pdf
#https://raw.githubusercontent.com/igiteam/igi1-macbook-3d-workstation/refs/heads/main/rapsberry-pi5-ssd/rapsberry-pi-5-portable-forgejogitlf-ubuntu.pdf

# Raspberry Pi 5 (8GB)
# https://www.amazon.co.uk/gp/product/B0CK2FCG1K/ref=ox_sc_act_title_6?smid=A2TRIJRGK1887G&psc=1

# Geekworm X1004 PCIe to Dual M.2 NVMe 2280 SSD HAT for Raspberry Pi 5
# https://www.amazon.co.uk/gp/product/B0D22JPQRB/ref=ewc_pr_img_2?smid=A2PBQMPS4N8CJ2&psc=1

# Geekworm P579 Raspberry Pi 5 Case | Support Top PCIe M.2 NVMe
# https://www.amazon.co.uk/gp/product/B0CRB3DT5M/ref=ewc_pr_img_1?smid=A2PBQMPS4N8CJ2&th=1

# Raspberry Pi Active Cooler for Raspberry Pi 5
# https://www.amazon.co.uk/gp/product/B0CLXZBR5P/ref=ox_sc_act_title_5?smid=A2YR4ZV515UPJ9&psc=1

# iRasptek 27W 5.1V/5A USB-C PD Power Adapter for Raspberry Pi 5
# https://www.amazon.co.uk/gp/product/B0D12H1N4L/ref=ox_sc_act_title_7?smid=A2KRCSBCGVE5NF&psc=1

# Adafruit RGB Negative 16x2 LCD+Keypad Kit for Raspberry Pi [ADA1110]
# https://www.amazon.co.uk/gp/product/B00XW2LAAM/ref=ox_sc_act_title_8?smid=A1BTLUV6GKJM47&psc=1

# Patriot P320 512GB Internal SSD - NVMe PCIe Gen 3x4 - M.2 2280 
# https://www.amazon.co.uk/gp/product/B0D4RCRNHG/ref=ox_sc_act_title_2?smid=A1G2FC5CI8M2YB&psc=1

# Patriot Memory P300 M.2 Pcie Gen3 x4 512GB low-power consumption
# https://www.amazon.co.uk/gp/product/B082BJ4679/ref=ox_sc_act_title_1?smid=A1G2FC5CI8M2YB&psc=1

# KEXIN Micro SD Card 16GB, MicroSDHC UHS-I Class 10 A1 U1
# https://www.amazon.co.uk/gp/product/B0GT3Z7C8W/ref=ox_sc_act_title_4?smid=A2PW452KB0OCY3&psc=1

# UANTIN SD Card Reader, Dual Slots USB A & USB C to Micro SD Card
# https://www.amazon.co.uk/gp/product/B0F2H3WFCR/ref=ox_sc_act_title_3?smid=A323W53PMQ1B00&psc=1

# The job is exactly one thing:
#     Power on the Pi (anywhere, any network)
#     LCD shows "No Wi-Fi. Configure?"
#     User picks network, types password with buttons
#     Pi connects
#     LCD shows the assigned IP address
#     User points their domain's A record to that IP
#     Done
#
# Just a boot-time script that runs before anything else and
# gets the Pi online.
#
# 🎯 The Flow, Precisely
# [Power on]
#     ↓
# [systemd starts wifi-lcd.service]
#     ↓
# [LCD shows: "Scanning WiFi..."]
#     ↓
# [nmcli scan → list of SSIDs]
#     ↓
# [LCD: "Network 1/5: MyWiFi"]  ← Up/Down to scroll, Select to pick
#     ↓
# [LCD: "Password:" on line 1, typed string on line 2]
#     ↓
# [Up/Down = change char at cursor]
# [Left/Right = move cursor / append / backspace]
# [Select = confirm]
#     ↓
# [LCD: "Connecting..."]
#     ↓
# [Success?]
#     ├── Yes → [LCD: "Connected!" / "IP: 192.168.1.42"]
#     └── No  → [LCD: "Failed. Retry?"] → back to network picker
#     ↓
# [Idle screen shows current IP until reboot]
#
# 🧩 The Architecture
# Three files, all standalone:
#   /usr/local/bin/wifi-lcd.sh            ← main launcher (shell)
#   /usr/local/bin/wifi-lcd-helper.py     ← LCD + button reader + state machine (Python)
#   /etc/systemd/system/wifi-lcd.service  ← runs on boot
#
# And this installer:
#   rapsberry_pi_wifi_checker_lcd.sh                   ← one-shot install (chmod, deps, systemd unit)
#
# 🔑 Key Design Decisions
#
# 1. Runs before login, but after network stack is up.
#    After=network.target and Before=getty.target. It blocks the
#    console until Wi-Fi is configured, but SSH comes up the moment
#    it connects.
#
# 2. Doesn't run if Wi-Fi is already connected.
#    if nmcli -t -f GENERAL.STATE device show wlan0 | grep -q "connected"; then
#        # already online, just show IP on LCD and exit
#    fi
#    This means you only see the configurator when the Pi genuinely
#    has no network. On a normal boot at home, it skips itself entirely.
#
# 3. Doesn't fight NetworkManager.
#    Uses nmcli for everything:
#      nmcli -t -f SSID,SIGNAL device wifi list       — scan
#      nmcli device wifi connect "$SSID" password "$PASS" — connect
#      nmcli -t -f IP4.ADDRESS device show wlan0      — get IP
#
# 4. The Python helper exits when done.
#    It doesn't stay resident. Once Wi-Fi is configured and the IP is
#    shown, the helper exits and the service completes. This means the
#    LCD is free for other things later (like your Forgejo status display).
#
# 5. Optional: leave the idle screen running.
#    If you want the LCD to keep showing the IP after configuration,
#    the helper can loop forever on the idle screen instead of exiting.
#    Set STAY_RESIDENT=1 in /etc/wifi-lcd.conf to enable.
#
# 📝 The Character Set
# Exactly what you asked for:
#   a b c d e f g h i j k l m n o p q r s t u v w x y z
#   A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
#   0 1 2 3 4 5 6 7 8 9
#   . - _ ! @ #
#
# That's 26 + 26 + 10 + 6 = 68 characters. Up/Down cycles through
# them. Ordered so lowercase is first (most common), then digits,
# then uppercase, then symbols. That means short passwords are fast
# to type.
#
# 🎮 Button Behavior
# Button  Short press                          Long press
# Up      Previous character                   (nothing special)
# Down    Next character                       (nothing special)
# Left    Move cursor left                     Delete character to the left
# Right   Move cursor right, append blank      (nothing special)
# Select  Confirm / advance screen             Cancel current operation
#
# Long-press threshold: 1000ms.
#
# Backspace semantics:
#   - If cursor is at position N and you long-press Left, the character
#     at position N-1 is deleted, everything shifts left, and the cursor
#     moves back to N-1.
#   - If cursor is at position 0, long-Left does nothing.
#
# This matches how a printer display works, and how most single-line
# text entry works on embedded UIs.
#
# 🖥️ Display Layout
# Scanning screen:
#   Scanning WiFi...
#   Please wait...
#
# Network picker:
#   Line 1: Network 2/5
#   Line 2: MyWiFi_5G
#   Up/Down moves through the list.
#
# Password entry:
#   Line 1: MyWiFi_5G
#   Line 2: abc123_ <
#   The < on line 2 marks the cursor. When the password is longer
#   than 14 characters, the display scrolls so the cursor is always
#   visible.
#
# Connecting:
#   Connecting to
#   MyWiFi_5G...
#
# Success:
#   Connected!
#   IP: 192.168.1.42
#
# Failure:
#   Failed!
#   Select=retry
#
# ❓ Two Quick Questions (answered)
# After showing the IP, should the helper exit or stay running?
#     Exit = LCD goes blank, service done, console returns. Cleanest for boot.
#     Stay = LCD keeps showing the IP, useful for "what's my IP again?" later.
#            Blocks the console.
#     → Default: Exit. Set STAY_RESIDENT=1 in /etc/wifi-lcd.conf to Stay.
#
# What if the user has no network to connect to at all?
#     Show "No networks found. Retry?"
#     Or drop to a fallback hotspot mode where the Pi creates its own Wi-Fi
#     and the user connects from a phone?
#     The second option means the LCD is unnecessary — they'd just open a
#     browser. But it's a good backup if the LCD path fails.
#     → Default: Show "No networks / Select=retry". Hotspot fallback is a
#                future addition.
# ============================================================

set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
# An image of the device
IMAGE_URL='https://raw.githubusercontent.com/igiteam/igi1-macbook-3d-workstation/refs/heads/main/adafruit-16x2-lcd-keypad-kit-for-raspberry-pi.jpg'

log()     { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${MAGENTA}[SUCCESS]${NC} $1"; }

info "📷 Hardware reference image:"
info "   $IMAGE_URL"

# ============= REQUIRE ROOT =============
if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo bash $0"
fi

log "🚀 Installing Wi-Fi LCD Configurator..."

# ============= DETECT USER & HOME =============
# Default to 'pi' on Raspberry Pi OS, fall back to first non-root user.
TARGET_USER="${SUDO_USER:-pi}"
if ! id "$TARGET_USER" &>/dev/null; then
    TARGET_USER=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd)
fi
[ -z "$TARGET_USER" ] && error "Could not detect a non-root user"

TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
info "Target user: $TARGET_USER ($TARGET_HOME)"

# ============= INSTALL DEPENDENCIES =============
log "📦 Installing dependencies..."
apt-get update -qq
apt-get install -y -qq \
    python3 \
    python3-pip \
    python3-smbus \
    i2c-tools \
    network-manager \
    || error "Failed to install dependencies"

# Adafruit CharLCD library (pip - works on Pi 3/4/5)
log "📦 Installing Adafruit_CharLCD..."
pip3 install --quiet --break-system-packages \
    Adafruit-Blinka \
    adafruit-circuitpython-charlcd \
    || pip3 install --quiet \
       Adafruit-Blinka \
       adafruit-circuitpython-charlcd \
    || warn "pip install failed - will try alternate path"

# ============= ENABLE I2C =============
log "🔧 Enabling I2C..."
if ! grep -q "^dtparam=i2c_arm=on" /boot/firmware/config.txt 2>/dev/null; then
    # Pi OS Bookworm uses /boot/firmware/config.txt
    if [ -f /boot/firmware/config.txt ]; then
        echo "dtparam=i2c_arm=on" >> /boot/firmware/config.txt
    elif [ -f /boot/config.txt ]; then
        echo "dtparam=i2c_arm=on" >> /boot/config.txt
    fi
fi

# Load i2c-dev module immediately (and at boot)
modprobe i2c-dev 2>/dev/null || true
echo "i2c-dev" > /etc/modules-load.d/i2c-dev.conf

# Add target user to i2c group
usermod -aG i2c "$TARGET_USER" 2>/dev/null || true

# ============= VERIFY LCD IS PRESENT =============
log "🔍 Checking for Adafruit LCD at I2C 0x20..."
if command -v i2cdetect &>/dev/null; then
    if i2cdetect -y 1 2>/dev/null | grep -q "20"; then
        log "✅ Adafruit LCD + Keypad detected at 0x20"
    else
        warn "⚠️  No I2C device at 0x20 - LCD may not be connected"
        warn "    Wiring check: SDA=GPIO2, SCL=GPIO3, 5V, GND"
        warn "    Continuing install anyway..."
    fi
fi

# ============= WRITE HELPER (PYTHON) =============
log "📝 Writing /usr/local/bin/wifi-lcd-helper.py..."
cat > /usr/local/bin/wifi-lcd-helper.py << 'PYEOF'
#!/usr/bin/env python3
# ============================================================
# Raspberry Pi Portable Wi-Fi LCD Configurator - PYTHON HELPER
# ============================================================
# See rapsberry_pi_wifi_checker_lcd.sh for the full design doc.
#
# This file contains the state machine:
#   STATE_SCAN         → scan for networks
#   STATE_PICK         → network picker
#   STATE_PASSWORD     → character entry
#   STATE_CONNECT      → nmcli connect
#   STATE_SUCCESS      → show IP
#   STATE_FAIL         → show error, offer retry
#   STATE_IDLE         → show IP (only if STAY_RESIDENT=1)
# ============================================================

import os
import sys
import time
import subprocess
import logging

logging.basicConfig(
    filename='/var/log/wifi-lcd.log',
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s'
)

try:
    import board
    import busio
    import digitalio
    from adafruit_character_lcd.character_lcd_i2c import Character_LCD_I2C
    import adafruit_mcp230xx
    HAS_LCD = True
except ImportError as e:
    logging.error(f"LCD libraries not available: {e}")
    HAS_LCD = False

# ============= HARDWARE SETUP =============
LCD_ADDR = 0x20
LCD_COLS = 16
LCD_ROWS = 2

# MCP23017 button pin mapping (Adafruit LCD Plate)
BUTTON_SELECT = 0
BUTTON_RIGHT  = 1
BUTTON_DOWN   = 2
BUTTON_UP     = 3
BUTTON_LEFT   = 4

# ============= CHARACTER SET =============
# a-z, A-Z, 0-9, . - _ ! @ #
CHARSET = (
    'abcdefghijklmnopqrstuvwxyz'
    '0123456789'
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    '.-_!@#'
)

# ============= TIMING =============
LOOP_DELAY = 0.05        # 50ms main loop
LONG_PRESS_MS = 1000     # 1s = long press
DEBOUNCE_MS = 80         # ignore repeats within 80ms

# ============= STATE CONSTANTS =============
STATE_SCAN     = 'SCAN'
STATE_PICK     = 'PICK'
STATE_PASSWORD = 'PASSWORD'
STATE_CONNECT  = 'CONNECT'
STATE_SUCCESS  = 'SUCCESS'
STATE_FAIL     = 'FAIL'
STATE_IDLE     = 'IDLE'

# ============= HARDWARE INIT =============
if HAS_LCD:
    try:
        i2c = busio.I2C(board.SCL, board.SDA)
        lcd = Character_LCD_I2C(i2c, LCD_COLS, LCD_ROWS, address=LCD_ADDR)
        mcp = adafruit_mcp230xx.MCP23017(i2c, address=LCD_ADDR)

        # Configure button pins as inputs with pull-up
        buttons = {}
        for name, pin in [
            ('SELECT', BUTTON_SELECT),
            ('RIGHT',  BUTTON_RIGHT),
            ('DOWN',   BUTTON_DOWN),
            ('UP',     BUTTON_UP),
            ('LEFT',   BUTTON_LEFT),
        ]:
            b = mcp.get_pin(pin)
            b.direction = digitalio.Direction.INPUT
            b.pull = digitalio.Pull.UP
            buttons[name] = b

        lcd.clear()
        lcd.backlight = True
    except Exception as e:
        logging.error(f"LCD init failed: {e}")
        HAS_LCD = False


def show(line1, line2=""):
    """Write two lines to the LCD. Silent if LCD is missing."""
    if not HAS_LCD:
        logging.info(f"LCD[{line1}|{line2}]")
        return
    try:
        lcd.clear()
        # Truncate safely
        line1 = line1[:LCD_COLS]
        line2 = line2[:LCD_COLS]
        lcd.message = line1 + "\n" + line2
    except Exception as e:
        logging.error(f"LCD write failed: {e}")


def pressed(name):
    """Return True if button is currently pressed (active LOW)."""
    if not HAS_LCD or name not in buttons:
        return False
    try:
        return not buttons[name].value
    except Exception:
        return False


class ButtonDebouncer:
    """Tracks press/release and long-press for one button."""
    def __init__(self, name):
        self.name = name
        self.last_state = False
        self.press_start = 0.0
        self.last_event = 0.0
        self.long_fired = False

    def update(self, is_down):
        """Return one of: None, 'short', 'long'."""
        now = time.time() * 1000  # ms
        event = None

        if is_down and not self.last_state:
            # Press started
            self.press_start = now
            self.last_event = now
            self.long_fired = False
        elif is_down and self.last_state:
            # Still held - fire long press once
            if not self.long_fired and (now - self.press_start) >= LONG_PRESS_MS:
                self.long_fired = True
                event = 'long'
        elif not is_down and self.last_state:
            # Released - fire short press if long didn't fire
            if not self.long_fired and (now - self.last_event) >= DEBOUNCE_MS:
                event = 'short'

        self.last_state = is_down
        return event


# ============= WI-FI HELPERS =============
def wifi_scan():
    """Return list of (ssid, signal) sorted by signal desc, deduped."""
    try:
        out = subprocess.check_output(
            ['nmcli', '-t', '-f', 'SSID,SIGNAL', 'device', 'wifi', 'list'],
            stderr=subprocess.DEVNULL,
            timeout=15
        ).decode('utf-8', errors='replace')
    except Exception as e:
        logging.error(f"nmcli scan failed: {e}")
        return []

    seen = {}
    for line in out.splitlines():
        if ':' not in line:
            continue
        # nmcli escapes colons in SSIDs as \:
        parts = line.replace('\\:', '\x00').split(':')
        if len(parts) < 2:
            continue
        ssid = parts[0].replace('\x00', ':').strip()
        try:
            signal = int(parts[1])
        except ValueError:
            continue
        if not ssid:
            continue
        if ssid not in seen or signal > seen[ssid]:
            seen[ssid] = signal

    return sorted(seen.items(), key=lambda x: -x[1])


def wifi_connect(ssid, password):
    """Try to connect. Return (success, message)."""
    try:
        result = subprocess.run(
            ['nmcli', 'device', 'wifi', 'connect', ssid, 'password', password],
            capture_output=True,
            text=True,
            timeout=45
        )
        if result.returncode == 0:
            return True, "Connected"
        return False, (result.stderr or result.stdout or "Failed").strip()
    except subprocess.TimeoutExpired:
        return False, "Timeout"
    except Exception as e:
        return False, str(e)


def get_wifi_ip():
    """Return IPv4 address of wlan0, or '0.0.0.0'."""
    try:
        out = subprocess.check_output(
            ['nmcli', '-t', '-f', 'IP4.ADDRESS', 'device', 'show', 'wlan0'],
            stderr=subprocess.DEVNULL,
            timeout=5
        ).decode('utf-8', errors='replace')
    except Exception:
        return '0.0.0.0'

    for line in out.splitlines():
        if ':' in line:
            addr = line.split(':', 1)[1].strip()
            return addr.split('/')[0]
    return '0.0.0.0'


def is_wifi_connected():
    """Check if wlan0 is already connected."""
    try:
        out = subprocess.check_output(
            ['nmcli', '-t', '-f', 'GENERAL.STATE', 'device', 'show', 'wlan0'],
            stderr=subprocess.DEVNULL,
            timeout=5
        ).decode('utf-8', errors='replace')
        return 'connected' in out.lower()
    except Exception:
        return False


# ============= STATE MACHINE =============
class StateMachine:
    def __init__(self):
        self.state = STATE_SCAN
        self.networks = []
        self.net_index = 0
        self.ssid = ""
        self.password = ""
        self.cursor = 0
        self.connect_msg = ""
        self.stay_resident = os.environ.get('STAY_RESIDENT', '0') == '1'

        # Debouncers for all 5 buttons
        self.deb = {
            'UP':     ButtonDebouncer('UP'),
            'DOWN':   ButtonDebouncer('DOWN'),
            'LEFT':   ButtonDebouncer('LEFT'),
            'RIGHT':  ButtonDebouncer('RIGHT'),
            'SELECT': ButtonDebouncer('SELECT'),
        }

    # -------- Rendering --------
    def render(self):
        if self.state == STATE_SCAN:
            show("Scanning WiFi...", "Please wait...")

        elif self.state == STATE_PICK:
            if not self.networks:
                show("No networks", "Select=retry")
            else:
                idx = self.net_index + 1
                total = len(self.networks)
                ssid = self.networks[self.net_index][0]
                show(f"Network {idx}/{total}", ssid[:16])

        elif self.state == STATE_PASSWORD:
            # Show SSID on line 1, password + cursor on line 2
            # Scroll password so cursor is always visible
            max_visible = 15  # leave room for cursor marker
            start = max(0, self.cursor - max_visible + 1)
            visible = self.password[start:start + max_visible]
            marker_pos = self.cursor - start
            # Insert cursor marker
            if marker_pos < len(visible):
                line2 = visible[:marker_pos] + '<' + visible[marker_pos + 1:]
            else:
                line2 = visible + '<'
            show(self.ssid[:16], line2)

        elif self.state == STATE_CONNECT:
            show(f"Connecting to", f"{self.ssid[:16]}...")

        elif self.state == STATE_SUCCESS:
            ip = get_wifi_ip()
            show("Connected!", f"IP: {ip}")

        elif self.state == STATE_FAIL:
            show("Failed!", "Select=retry")

        elif self.state == STATE_IDLE:
            ip = get_wifi_ip()
            show("WiFi OK", f"IP: {ip}")

    # -------- Button handlers --------
    def on_up(self):
        if self.state == STATE_PICK:
            if self.networks:
                self.net_index = (self.net_index - 1) % len(self.networks)
        elif self.state == STATE_PASSWORD:
            # Cycle character at cursor
            if self.cursor < len(self.password):
                c = self.password[self.cursor]
                i = CHARSET.find(c)
                i = (i - 1) % len(CHARSET) if i >= 0 else 0
                self.password = (
                    self.password[:self.cursor]
                    + CHARSET[i]
                    + self.password[self.cursor + 1:]
                )

    def on_down(self):
        if self.state == STATE_PICK:
            if self.networks:
                self.net_index = (self.net_index + 1) % len(self.networks)
        elif self.state == STATE_PASSWORD:
            if self.cursor < len(self.password):
                c = self.password[self.cursor]
                i = CHARSET.find(c)
                i = (i + 1) % len(CHARSET) if i >= 0 else 0
                self.password = (
                    self.password[:self.cursor]
                    + CHARSET[i]
                    + self.password[self.cursor + 1:]
                )

    def on_left_short(self):
        if self.state == STATE_PASSWORD:
            if self.cursor > 0:
                self.cursor -= 1

    def on_left_long(self):
        if self.state == STATE_PASSWORD:
            if self.cursor > 0:
                # Delete char to the left of cursor
                self.password = (
                    self.password[:self.cursor - 1]
                    + self.password[self.cursor:]
                )
                self.cursor -= 1

    def on_right(self):
        if self.state == STATE_PASSWORD:
            if self.cursor < len(self.password):
                self.cursor += 1
            else:
                # Append a blank character
                self.password += 'a'
                self.cursor = len(self.password) - 1

    def on_select_short(self):
        if self.state == STATE_SCAN:
            self.start_scan()
        elif self.state == STATE_PICK:
            if self.networks:
                self.ssid = self.networks[self.net_index][0]
                self.password = ""
                self.cursor = 0
                self.state = STATE_PASSWORD
        elif self.state == STATE_PASSWORD:
            self.do_connect()
        elif self.state == STATE_FAIL:
            self.start_scan()
        elif self.state == STATE_SUCCESS:
            if not self.stay_resident:
                self.state = STATE_IDLE
                return
            self.state = STATE_IDLE

    def on_select_long(self):
        # Cancel current operation
        if self.state == STATE_PASSWORD:
            self.state = STATE_PICK
            self.password = ""
            self.cursor = 0
        elif self.state in (STATE_CONNECT, STATE_SUCCESS, STATE_FAIL):
            self.start_scan()

    # -------- Transitions --------
    def start_scan(self):
        self.state = STATE_SCAN
        self.render()
        self.networks = wifi_scan()
        logging.info(f"Scan found {len(self.networks)} networks")
        if not self.networks:
            self.state = STATE_FAIL
        else:
            self.net_index = 0
            self.state = STATE_PICK

    def do_connect(self):
        self.state = STATE_CONNECT
        self.render()
        logging.info(f"Connecting to {self.ssid}")
        ok, msg = wifi_connect(self.ssid, self.password)
        if ok:
            logging.info(f"Connected to {self.ssid}")
            self.state = STATE_SUCCESS
        else:
            logging.error(f"Connect failed: {msg}")
            self.state = STATE_FAIL

    # -------- Main loop --------
    def run(self):
        # If already connected, skip the whole configurator
        if is_wifi_connected():
            logging.info("Already connected - showing IP and exiting")
            self.state = STATE_IDLE
            self.render()
            time.sleep(5)
            if not self.stay_resident:
                return
            # Stay resident: loop on idle screen
            while True:
                self.render()
                time.sleep(5)

        # Normal boot: start scanning
        self.start_scan()

        while True:
            # Poll all buttons
            for name, b in self.deb.items():
                is_down = pressed(name)
                event = b.update(is_down)
                if event == 'short':
                    if name == 'UP':
                        self.on_up()
                    elif name == 'DOWN':
                        self.on_down()
                    elif name == 'LEFT':
                        self.on_left_short()
                    elif name == 'RIGHT':
                        self.on_right()
                    elif name == 'SELECT':
                        self.on_select_short()
                elif event == 'long':
                    if name == 'LEFT':
                        self.on_left_long()
                    elif name == 'SELECT':
                        self.on_select_long()

            self.render()

            # Exit when done (unless resident)
            if self.state == STATE_IDLE and not self.stay_resident:
                time.sleep(3)
                return

            time.sleep(LOOP_DELAY)


def main():
    if not HAS_LCD:
        logging.error("LCD not available - exiting")
        # Fall back to non-interactive: just wait for NetworkManager
        # to bring up wlan0 from saved profile
        for _ in range(30):
            if is_wifi_connected():
                ip = get_wifi_ip()
                logging.info(f"WiFi came up: {ip}")
                return
            time.sleep(2)
        logging.error("No WiFi and no LCD - giving up")
        return

    sm = StateMachine()
    try:
        sm.run()
    except KeyboardInterrupt:
        logging.info("Interrupted")
    finally:
        if HAS_LCD and not sm.stay_resident:
            try:
                lcd.clear()
                lcd.backlight = False
            except Exception:
                pass


if __name__ == '__main__':
    main()
PYEOF

chmod +x /usr/local/bin/wifi-lcd-helper.py

# ============= WRITE SHELL LAUNCHER =============
log "📝 Writing /usr/local/bin/wifi-lcd.sh..."
cat > /usr/local/bin/wifi-lcd.sh << 'SHEOF'
#!/bin/bash
# ============================================================
# Raspberry Pi Portable Wi-Fi LCD Configurator - SHELL LAUNCHER
# ============================================================
# This wrapper:
#   1. Waits for NetworkManager to be ready
#   2. Waits for the i2c bus to be ready
#   3. Runs the Python helper
#   4. Cleans up on exit
#
# It is meant to be called by systemd at boot.
# See rapsberry_pi_wifi_checker_lcd.sh for the full design doc.
# ============================================================

LOG_TAG="wifi-lcd"
logger -t "$LOG_TAG" "Launcher starting"

# Wait for NetworkManager
for i in $(seq 1 30); do
    if nmcli -t -f RUNNING general 2>/dev/null | grep -q "running"; then
        logger -t "$LOG_TAG" "NetworkManager ready"
        break
    fi
    sleep 1
done

# Wait for wlan0 to exist
for i in $(seq 1 30); do
    if nmcli -t -f DEVICE device 2>/dev/null | grep -q "^wlan0$"; then
        logger -t "$LOG_TAG" "wlan0 present"
        break
    fi
    sleep 1
done

# Wait for i2c bus
for i in $(seq 1 15); do
    if [ -e /dev/i2c-1 ]; then
        logger -t "$LOG_TAG" "i2c-1 ready"
        break
    fi
    sleep 1
done

# Give NetworkManager a moment to auto-connect to a saved profile
sleep 3

# Run the helper
exec /usr/local/bin/wifi-lcd-helper.py
SHEOF

chmod +x /usr/local/bin/wifi-lcd.sh

# ============= WRITE CONFIG =============
log "📝 Writing /etc/wifi-lcd.conf..."
cat > /etc/wifi-lcd.conf << 'CFGEOF'
# Wi-Fi LCD Configurator options
#
# STAY_RESIDENT=1  → keep showing IP on the LCD forever
# STAY_RESIDENT=0  → exit after showing IP (frees the LCD for other use)
STAY_RESIDENT=0
CFGEOF

# ============= WRITE SYSTEMD UNIT =============
log "📝 Writing /etc/systemd/system/wifi-lcd.service..."
cat > /etc/systemd/system/wifi-lcd.service << 'UNITEOF'
[Unit]
Description=Portable Pi Wi-Fi LCD Configurator
Documentation=file:/usr/local/bin/wifi-lcd.sh
After=network.target NetworkManager.service
Wants=NetworkManager.service
Before=getty.target
Conflicts=getty@tty1.service

[Service]
Type=oneshot
RemainAfterExit=yes
EnvironmentFile=-/etc/wifi-lcd.conf
ExecStart=/usr/local/bin/wifi-lcd.sh
StandardOutput=journal
StandardError=journal
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
UNITEOF

# ============= ENABLE SERVICE =============
log "🔧 Enabling systemd service..."
systemctl daemon-reload
systemctl enable wifi-lcd.service

# ============= WRITE UNINSTALL SCRIPT =============
log "📝 Writing /usr/local/bin/uninstall-wifi-lcd.sh..."
cat > /usr/local/bin/uninstall-wifi-lcd.sh << 'UNEOF'
#!/bin/bash
# ============================================================
# Wi-Fi LCD Configurator - UNINSTALLER
# ============================================================
set -e

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash $0"
    exit 1
fi

echo "[*] Stopping and disabling service..."
systemctl stop wifi-lcd.service 2>/dev/null || true
systemctl disable wifi-lcd.service 2>/dev/null || true

echo "[*] Removing systemd unit..."
rm -f /etc/systemd/system/wifi-lcd.service
systemctl daemon-reload

echo "[*] Removing binaries..."
rm -f /usr/local/bin/wifi-lcd.sh
rm -f /usr/local/bin/wifi-lcd-helper.py
rm -f /usr/local/bin/uninstall-wifi-lcd.sh

echo "[*] Removing config..."
rm -f /etc/wifi-lcd.conf

echo "[*] Removing logs..."
rm -f /var/log/wifi-lcd.log

echo "[*] Leaving I2C enabled (may be used by other things)."
echo "[*] Leaving Adafruit pip packages installed."
echo ""
echo "✅ Wi-Fi LCD Configurator removed."
UNEOF

chmod +x /usr/local/bin/uninstall-wifi-lcd.sh

# ============= TEST PYTHON IMPORT =============
log "🔍 Testing Python helper (dry run)..."
python3 -c "
import sys
sys.path.insert(0, '/usr/local/bin')
try:
    import importlib.util
    spec = importlib.util.spec_from_file_location('helper', '/usr/local/bin/wifi-lcd-helper.py')
    print('✅ Helper loads cleanly')
except Exception as e:
    print(f'⚠️  Helper import warning: {e}')
" || warn "Python syntax check reported an issue"

# ============= DONE =============
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║        WI-FI LCD CONFIGURATOR INSTALLED SUCCESSFULLY!          ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
success "✅ Installed files:"
info "   • /usr/local/bin/wifi-lcd.sh"
info "   • /usr/local/bin/wifi-lcd-helper.py"
info "   • /usr/local/bin/uninstall-wifi-lcd.sh"
info "   • /etc/systemd/system/wifi-lcd.service"
info "   • /etc/wifi-lcd.conf"
echo ""
info "🎯 Commands:"
info "   sudo systemctl start wifi-lcd      # Run now"
info "   sudo systemctl status wifi-lcd     # Check status"
info "   sudo journalctl -u wifi-lcd -f     # Follow logs"
info "   tail -f /var/log/wifi-lcd.log      # Python log"
info "   sudo bash /usr/local/bin/uninstall-wifi-lcd.sh  # Remove"
echo ""
info "🔌 Hardware check:"
info "   Run: i2cdetect -y 1"
info "   Expect: device at 0x20"
echo ""
warn "⚠️  Reboot to activate the boot-time service."
echo ""
success "✨ Done! Reboot the Pi to test the LCD Wi-Fi configurator."

# 🧪 Pre-Deploy Sanity Check
# # 1. Verify shell syntax
# bash -n rapsberry_pi_wifi_checker_lcd.sh

# # 2. Verify Python helper syntax (extracted)
# awk '/^PYEOF$/{p=0} p{print} /^cat > \/usr\/local\/bin\/wifi-lcd-helper.py/{p=1}' rapsberry_pi_wifi_checker_lcd.sh > /tmp/check.py
# python3 -m py_compile /tmp/check.py && echo "Python OK"

# # Both should return clean. If they do, scp it to the Pi and run:
# sudo bash rapsberry_pi_wifi_checker_lcd.sh
# sudo reboot

# On the Pi (installation time)

# You run sudo bash rapsberry_pi_wifi_checker_lcd.sh once. It does the following:
#     Checks you're root. Bails if not.
#     Finds your username. Looks for SUDO_USER, falls back to pi, falls back to the first non-root user in /etc/passwd. Prints it.
#     Installs packages. Runs apt-get install for python3, python3-pip, python3-smbus, i2c-tools, network-manager.
#     Installs Python libraries. Runs pip3 install for Adafruit-Blinka and adafruit-circuitpython-charlcd. These are the libraries that talk to the LCD and the buttons over I2C.
#     Enables I2C. Adds dtparam=i2c_arm=on to /boot/firmware/config.txt if not already there. Loads the i2c-dev kernel module. Adds your user to the i2c group.
#     Checks for the LCD. Runs i2cdetect -y 1 and looks for a device at address 0x20. If it's not there, warns you but continues.

#     Writes four files:
#         /usr/local/bin/wifi-lcd-helper.py — the Python state machine
#         /usr/local/bin/wifi-lcd.sh — the shell launcher
#         /etc/wifi-lcd.conf — options file (just STAY_RESIDENT=0)
#         /etc/systemd/system/wifi-lcd.service — the boot service
#         /usr/local/bin/uninstall-wifi-lcd.sh — the uninstaller

#     Makes them executable with chmod +x.
#     Enables the service so it starts on every boot.
#     Tests the Python helper by importing it — catches syntax errors.
#     Prints a big success banner with all the commands you can use.

# Nothing is running yet. Just files on disk and a systemd unit that's enabled but not started.
# On Every Boot (from now on)

# Here's the sequence systemd runs, in order:

# 1. Boot begins
#     NetworkManager starts
#     The kernel loads the i2c-dev module
#     wlan0 appears as a device

# 2. wifi-lcd.service starts
#     Because it has After=network.target NetworkManager.service, systemd waits for those to be up first
#     Because it has Conflicts=getty@tty1.service, the login prompt on tty1 does not start yet
#     Because it has Before=getty.target, the console blocks until this service finishes

# 3. The shell launcher runs (/usr/local/bin/wifi-lcd.sh)
#     Logs "Launcher starting" to syslog
#     Waits up to 30 seconds for NetworkManager to report running
#     Waits up to 30 seconds for wlan0 to appear
#     Waits up to 15 seconds for /dev/i2c-1 to exist
#     Sleeps 3 more seconds to give NetworkManager a chance to auto-connect to a saved network
#     Then runs the Python helper with exec

# 4. The Python helper starts (/usr/local/bin/wifi-lcd-helper.py)
#     Initializes the LCD and the button pins
#     Checks if wlan0 is already connected

# 🚦 Two Paths from Here
# Path A — Already connected (normal boot at home)
# If nmcli reports wlan0 as connected:
#     Shows WiFi OK on line 1 and IP: 192.168.1.42 on line 2
#     Waits 5 seconds
#     If STAY_RESIDENT=0: turns off the backlight, clears the LCD, and exits. The service finishes. The login prompt comes back. The Pi is now a normal SSH-able server.
#     If STAY_RESIDENT=1: keeps looping — re-renders the same IP screen every 5 seconds forever.

# Path B — Not connected (new network, portable use)
# If wlan0 is not connected, the configurator takes over:
# Step 1: Scanning
#     LCD shows Scanning WiFi... / Please wait...
#     Python runs nmcli -t -f SSID,SIGNAL device wifi list
#     Parses the output into a list of (ssid, signal) tuples
#     Deduplicates by SSID (keeps the strongest signal for each)
#     Sorts by signal strength, strongest first

# Step 2: Network picker
#     If no networks found: LCD shows No networks / Select=retry
#     If networks found: LCD shows Network 1/N on line 1, the SSID on line 2
#     Up button: previous network
#     Down button: next network
#     Select (short press): choose this network → go to password entry

# Step 3: Password entry
#     LCD shows the SSID on line 1, the password being typed on line 2
#     A < marker shows the cursor position
#     The password scrolls if it's longer than 15 characters
#     Up: cycle the current character backwards through a-z 0-9 A-Z .-_!@#
#     Down: cycle the current character forwards
#     Left (short): move cursor left
#     Left (long press, 1s): delete the character to the left of the cursor
#     Right: move cursor right, or append a new blank a if at the end
#     Select (short): try to connect with this password
#     Select (long press): cancel and go back to the network picker

# Step 4: Connecting
#     LCD shows Connecting to / SSID...
#     Python runs nmcli device wifi connect SSID password PASSWORD
#     Waits up to 45 seconds

# Step 5a: Success
#     LCD shows Connected! / IP: 192.168.1.42
#     The real IP is fetched from nmcli -t -f IP4.ADDRESS device show wlan0
#     If STAY_RESIDENT=0: Select press → exits. Backlight off. Service done.
#     If STAY_RESIDENT=1: stays on this screen forever.

# Step 5b: Failure
#     LCD shows Failed! / Select=retry
#     Select (short): rescan and start over
#     Select (long): same thing — rescan

# 🔘 The Button Behavior, Precisely

# The Python helper polls all 5 buttons every 50 milliseconds. For each button, a ButtonDebouncer object tracks:
#     Was it pressed before? (edge detection)
#     When was it pressed? (to measure duration)
#     Has a long-press already fired for this hold? (so it doesn't fire twice)

# When a button goes from not-pressed to pressed:
#     Records the start time
#     Sets long_fired = False

# While a button is held:
#     If it's been held for ≥1000ms and long_fired is False: fires a 'long' event, sets long_fired = True

# When a button goes from pressed to not-pressed:
#     If long_fired is False and the press lasted ≥80ms: fires a 'short' event
#     Otherwise: does nothing (it was a long press, already handled)

# That 80ms debounce prevents jitter from firing multiple short presses.
# 📡 What nmcli Actually Does

# Scanning:
# nmcli -t -f SSID,SIGNAL device wifi list

# Returns lines like:
# MyWiFi:85
# Neighbour_5G:60
# :30

# Note the empty SSID line — that's a hidden network. The helper skips those.

# Colons inside SSIDs are escaped as \:, and the helper handles that by replacing \: with a null byte before splitting, then swapping back.

# Connecting:
# nmcli device wifi connect "MyWiFi" password "hunter2"

# Returns exit code 0 on success. Any non-zero means failure, and stderr has the reason.

# Getting the IP:
# nmcli -t -f IP4.ADDRESS device show wlan0

# Returns something like IP4.ADDRESS[1]:192.168.1.42/24. The helper splits on : and takes everything after, then splits on / and takes the first part.
# 🗂️ What's on Disk After Install
# /usr/local/bin/
# ├── wifi-lcd.sh               ← shell launcher
# ├── wifi-lcd-helper.py        ← Python state machine
# └── uninstall-wifi-lcd.sh     ← uninstaller

# /etc/
# ├── wifi-lcd.conf             ← options (STAY_RESIDENT=0)
# └── systemd/system/
#     └── wifi-lcd.service      ← boot service

# /var/log/
# └── wifi-lcd.log              ← Python log

# 🔄 The Logging
# Two separate logs:
# Systemd journal — captures everything stdout/stderr from the shell launcher, which mostly means syslog messages from logger -t wifi-lcd.

# View with:
# sudo journalctl -u wifi-lcd -f

# Python log file — /var/log/wifi-lcd.log, written by logging.basicConfig. Captures:
#     LCD init success/failure
#     Every scan and its result count
#     Every connect attempt and its result
#     Every LCD write failure

# View with:
# tail -f /var/log/wifi-lcd.log

# 🧹 What the Uninstaller Does
# Runs uninstall-wifi-lcd.sh:
#     Stops the service if running
#     Disables it so it won't start on boot
#     Removes /etc/systemd/system/wifi-lcd.service
#     Runs systemctl daemon-reload
#     Deletes all four files
#     Deletes the log

# Leaves behind:
#     I2C enabled in /boot/firmware/config.txt (harmless, other things may want it)
#     The Adafruit Python packages in site-packages (harmless)

# ⚠️ What It Doesn't Do
#     Doesn't reboot the Pi automatically
#     Doesn't set up a hotspot fallback if no networks are found
#     Doesn't handle WPA2-Enterprise (username + password)
#     Doesn't handle hidden SSIDs (user would need to type the SSID manually, which isn't implemented)
#     Doesn't persist the LCD state across reboots if STAY_RESIDENT=0
#     Doesn't talk to Forgejo, Docker, or anything else — it's purely Wi-Fi + IP display

# 🧪 Pre-Deploy Sanity Check
# Run these on your Mac (or wherever you have the file):
# # 1. Shell syntax check
# bash -n rapsberry_pi_wifi_checker_lcd.sh
# # Expected: no output (clean)

# # 2. Python syntax check (extract helper, compile it)
# awk '/^PYEOF$/{p=0} p{print} /^cat > \/usr\/local\/bin\/wifi-lcd-helper.py/{p=1}' rapsberry_pi_wifi_checker_lcd.sh > /tmp/check.py
# python3 -m py_compile /tmp/check.py && echo "Python OK"
# # Expected: "Python OK"

# If both pass, you're ready to ship.
# 🚀 Deploy
# # Copy to the Pi
# scp rapsberry_pi_wifi_checker_lcd.sh pi@<pi-ip>:~/

# # SSH in and run it
# ssh pi@<pi-ip>
# sudo bash rapsberry_pi_wifi_checker_lcd.sh

# # Reboot to test the boot-time flow
# sudo reboot

# On the next boot, the LCD should light up with Scanning WiFi... within ~15 seconds.
# 🎯 One Last Thing to Verify Before You Reboot

# After install but before rebooting, run this on the Pi:
# # Confirm the service is enabled
# sudo systemctl is-enabled wifi-lcd

# # Confirm i2c sees the LCD
# i2cdetect -y 1
# # Look for 0x20 in the grid

# # Optional: dry-run the configurator now
# sudo systemctl start wifi-lcd
# # Watch the LCD

# If i2cdetect doesn't show 0x20, the LCD isn't wired correctly or I2C isn't enabled yet. 
# The install script enables I2C in /boot/firmware/config.txt, but that only takes effect after a reboot. 
# So if i2cdetect shows nothing on the first run, don't panic — reboot and try again.