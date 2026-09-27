#!/bin/bash
# ============================================================
# Raspberry Pi Portable Studio - Cloudflare IP Tunnel Installer
# ============================================================
# This installs a Cloudflare Tunnel on your portable Pi.
#
# WHY:
#   Your ISP (UK residential) uses CGNAT, so you have no public IP.
#   This means inbound connections (game servers, HTTPS, Git) are
#   impossible to reach directly from the internet.
#
#   Cloudflare Tunnel creates an OUTBOUND-only connection from the
#   Pi to Cloudflare's edge. Traffic from wine.macosxjs.com flows
#   DOWN this tunnel to your Pi. No inbound ports needed, works
#   perfectly behind CGNAT.
#
# HOW IT FITS:
#   - Mac 1/2/3 keep using: https://wine.macosxjs.com/forgejolfs
#   - The Pi's public IP never matters again.
#   - When you move to NYC, just connect the Pi to Wi-Fi via the LCD.
#     The tunnel reconnects automatically. You do nothing.
#
# PREREQUISITES (Do these first!):
#   1. Domain wine.macosxjs.com must be added to Cloudflare (free).
#   2. Log in to Cloudflare Zero Trust Dashboard.
#   3. Go to Networks -> Tunnels -> Create a tunnel.
#   4. Choose "Cloudflared" -> "Docker".
#   5. Copy the docker run command's TOKEN (the long string).
#
# USAGE:
#   sudo bash install_ip_tunnel.sh
#   # When prompted, paste your Cloudflare Tunnel Token.
# ============================================================

set -e

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

log()     { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
warn()    { echo -e "${YELLOW}[WARNING]${NC} $1"; }
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${MAGENTA}[SUCCESS]${NC} $1"; }

# ============= REQUIRE ROOT =============
if [ "$EUID" -ne 0 ]; then
    error "Please run as root: sudo bash $0"
fi

log "🚀 Installing Cloudflare Tunnel for Portable Pi..."

# ============= VERIFY DOCKER =============
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker first."
fi
if ! docker info &> /dev/null; then
    error "Docker daemon is not running."
fi
log "✅ Docker is available"

# ============= PROMPT FOR TOKEN =============
echo ""
info "You need a Cloudflare Tunnel Token."
info "Get it from: Zero Trust Dashboard -> Networks -> Tunnels -> Create"
info "Choose 'Cloudflared' -> 'Docker'. Copy the token from the command."
echo ""
read -p "Paste your Cloudflare Tunnel Token: " TUNNEL_TOKEN

if [ -z "$TUNNEL_TOKEN" ]; then
    error "Token cannot be empty."
fi
if [[ ! "$TUNNEL_TOKEN" == *"eyJ"* ]]; then
    warn "Token doesn't look like a standard Cloudflare JWT (usually starts with 'eyJ')."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi
log "✅ Token received"

# ============= CREATE INSTALL DIRECTORY =============
INSTALL_DIR="/opt/cloudflare-tunnel"
log "📁 Creating $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# ============= CREATE .env FILE (TOKEN) =============
# We use an env file instead of passing token on command line
# for better security (token not in shell history or ps output)
log "📝 Writing .env file..."
cat > .env << ENVEOF
TUNNEL_TOKEN=${TUNNEL_TOKEN}
ENVEOF

chmod 600 .env

# ============= CREATE DOCKER COMPOSE =============
log "📝 Writing docker-compose.yml..."
cat > docker-compose.yml << 'COMPOSEEOF'
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflare-tunnel
    restart: unless-stopped
    command: tunnel --no-autoupdate run
    environment:
      TUNNEL_TOKEN: ${TUNNEL_TOKEN}
    # No ports exposed. Outbound-only connection.
COMPOSEEOF

# ============= START THE TUNNEL =============
log "🚀 Starting Cloudflare Tunnel..."
docker compose up -d

# ============= WAIT & VERIFY =============
log "⏳ Waiting for tunnel to connect..."
sleep 8

if docker ps --format '{{.Names}}' | grep -q "cloudflare-tunnel"; then
    success "✅ Cloudflare Tunnel container is running"
else
    error "Tunnel container failed to start. Check: docker logs cloudflare-tunnel"
fi

# Check logs for successful connection
if docker logs cloudflare-tunnel 2>&1 | grep -q "Connection.*registered"; then
    success "✅ Tunnel connected to Cloudflare!"
elif docker logs cloudflare-tunnel 2>&1 | grep -q "Registered tunnel connection"; then
    success "✅ Tunnel connected to Cloudflare!"
else
    warn "⚠️  Could not confirm connection. Check logs:"
    echo ""
    docker logs cloudflare-tunnel --tail 20
fi

# ============= FINAL OUTPUT =============
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║        CLOUDFLARE TUNNEL INSTALLED SUCCESSFULLY!               ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
success "✅ The tunnel is running."
echo ""
info "🎯 Next Steps:"
info "   1. Go back to Cloudflare Zero Trust -> Tunnels"
info "   2. Click your tunnel -> 'Public Hostname' tab"
info "   3. Add a Public Hostname:"
info "        Subdomain: wine"
info "        Domain:    macosxjs.com"
info "        Type:      HTTPS"
info "        URL:       https://localhost:3000"
info "   4. Save. Cloudflare will create the DNS record automatically."
echo ""
info "🔧 Management Commands:"
info "   docker logs cloudflare-tunnel           # View tunnel logs"
info "   docker restart cloudflare-tunnel        # Restart tunnel"
info "   docker compose -f $INSTALL_DIR/docker-compose.yml down   # Stop"
echo ""
info "📁 Config location: $INSTALL_DIR"
echo ""
success "✨ Done! Your Pi is now reachable via wine.macosxjs.com (once route is set)."

# 🚀 How to Use It
# Get your token first. Go to Cloudflare Zero Trust → Networks → Tunnels → Create a tunnel. 
# Choose "Cloudflared" and "Docker". Copy the long token string from the command shown .

# Run the installer on the Pi:
# sudo bash install_ip_tunnel.sh
# Paste the token when prompted.
# Add the Public Hostname in the Cloudflare dashboard:
#     Subdomain: wine
#     Domain: macosxjs.com
#     Type: HTTPS
#     URL: https://localhost:3000

# Once that's done, your Macs will reach https://wine.macosxjs.com/forgejolfs and it will route through the tunnel to your Pi, no matter where the Pi is or what its public IP is .
# ⚠️ Important Note About HTTPS Behind the Tunnel

# The search results mention that apps behind Cloudflare Tunnel need to know they're being served over HTTPS. Cloudflare terminates TLS at its edge and forwards plain HTTP to your Pi .

# For Forgejo, this means you must set ROOT_URL correctly in your app.ini:
# [server]
# ROOT_URL = https://wine.macosxjs.com/forgejolfs

# If you don't set this, Forgejo will generate broken http:// links and assets. 
# You likely already have this set from your earlier installer, but it's worth double-checking.
# Read article:
# https://theitbros.com/cloudflare-tunnel/

# 🎯 What It Does
# It installs a small program on your Pi called cloudflared. That program creates a permanent outbound connection from your Pi to Cloudflare's servers. 
# Cloudflare then forwards any traffic coming to wine.macosxjs.com down that connection to your Pi.

# Your Pi never needs a public IP. Your router never needs port forwarding. CGNAT doesn't matter. The tunnel is outbound-only, 
# so it works from any network, anywhere in the world.
# 🔌 Why This Solves Your CGNAT Problem

# Here's the fundamental issue:

# Without the tunnel:
# Mac → wine.macosxjs.com → DNS → your home IP
#                                    ↓
#                             [Blocked by CGNAT]
#                             Nothing is listening
#                             Mac fails to connect

# Your ISP's CGNAT layer drops the incoming connection because there's no unique public address for it to route to.

# With the tunnel:
# Pi → dials OUT to Cloudflare (works fine through CGNAT)
#          ↓
#      Tunnel established
#          ↓
# Mac → wine.macosxjs.com → Cloudflare edge
#                               ↓
#                          Finds the tunnel
#                               ↓
#                          Routes down to Pi
#                               ↓
#                          Forgejo responds

# The Pi starts the conversation. Cloudflare keeps it open. Traffic flows both ways through that already-open connection. CGNAT can't block an outbound connection that the Pi initiated.
# 📋 What Each Part of the Script Does
# 1. Checks Docker is installed. The tunnel runs as a Docker container, so Docker has to be there first.
# 2. Asks for your Cloudflare Tunnel Token. This is a secret string you get from the Cloudflare dashboard. It identifies your specific tunnel. Anyone with the token can run the tunnel, so treat it like a password.
# 3. Creates /opt/cloudflare-tunnel/. A home for the tunnel config.
# 4. Writes two files:
#     .env — stores your token in a file instead of on the command line. This is a security thing: if the token is on the command line, anyone running ps aux can see it. In a file with chmod 600, only root can read it.
#     docker-compose.yml — describes the container. It says:
#         Use the official cloudflare/cloudflared image
#         Name it cloudflare-tunnel
#         Auto-restart it if it crashes
#         Run it with --no-autoupdate (so the version is controlled by the Docker image, not by the app updating itself)
#         Pass the token from the .env file
#         Don't expose any ports — because it's outbound-only

# 5. Starts the container. docker compose up -d runs it in the background.
# 6. Verifies it's running. Checks the container is up, then looks in the logs for the phrase "Registered tunnel connection" — that's Cloudflare's way of saying "the tunnel is live."

# 7. Prints instructions for the last manual step: creating the Public Hostname in the Cloudflare dashboard.
# 🔗 The Missing Piece (Manual Step)

# The script sets up the tunnel, but it doesn't know what to route through it. That's the Public Hostname step:
#     Subdomain: wine
#     Domain: macosxjs.com
#     Type: HTTPS
#     URL: https://localhost:3000

# This tells Cloudflare: "When traffic comes in for wine.macosxjs.com, send it down the tunnel to localhost:3000 on the Pi."

# Once that's set, https://wine.macosxjs.com/forgejolfs works from your Macs, anywhere.
# 🎯 What Actually Happens After Setup

# At home in the UK:
#     Pi boots → Wi-Fi LCD configurator gets it online → cloudflared starts → tunnel reconnects
#     Macs reach wine.macosxjs.com → Cloudflare → tunnel → Pi → Forgejo responds

# You move to NYC:
#     Pi boots → Wi-Fi LCD configurator gets it online on the new Wi-Fi → cloudflared starts → tunnel reconnects
#     Macs reach wine.macosxjs.com → Cloudflare → tunnel → Pi → Forgejo responds

# Nothing on the Macs changes. Nothing on the Cloudflare side changes. The Pi's public IP changes, but Cloudflare doesn't care — the tunnel is already there.
# ⚠️ What It Doesn't Do
#     Doesn't set up HTTPS locally. Cloudflare terminates TLS at its edge and forwards plain HTTP to your Pi. 
#     That's fine because the tunnel itself is encrypted. But if you look at the traffic between Cloudflare and your Pi, it's HTTP.

#     Doesn't do SSH. The Cloudflare Tunnel used here only forwards HTTPS. If you ever wanted git@ over SSH, you'd need 
#     a separate configuration (Cloudflare Tunnel does support SSH, but Forgejo-over-SSH has known issues behind Cloudflare proxy).

#     Doesn't handle DNS. You still have to point wine.macosxjs.com at Cloudflare by moving your domain's nameservers to Cloudflare. 
#     Once Cloudflare manages the DNS, the Public Hostname step auto-creates the CNAME record.

#     Doesn't survive if Cloudflare is down. If Cloudflare's edge goes offline, your tunnel goes dark. That's rare but worth knowing.

# 🧠 The Mental Model
# Think of it like this:
#     Without a tunnel: You have a house with no street address. Nobody can find you.
#     With a VPS relay: You rent a mailbox in the city. Your house forwards mail to it. But you're paying rent on the mailbox.
#     With Cloudflare Tunnel: You get a free mailbox from Cloudflare, and your house is wired to it automatically. No rent. No address. Just works.

# The trade is that you're depending on Cloudflare's free service. They could change the terms, but for personal use they've offered this free for years.
# 🎯 Bottom Line
# The script installs a program that makes your Pi reachable from anywhere in the world without needing a public IP, without port forwarding, 
# and without paying for a VPS. It works around CGNAT by initiating the connection from the Pi side. 
# Once it's running, your Macs can reach wine.macosxjs.com no matter where the Pi is physically located.