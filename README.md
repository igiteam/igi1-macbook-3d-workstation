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