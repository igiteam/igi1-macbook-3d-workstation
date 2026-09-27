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