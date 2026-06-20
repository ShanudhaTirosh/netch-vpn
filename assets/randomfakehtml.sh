#!/bin/bash
##########################################################################
#  Netch VPN — camouflage decoy site generator
#  Writes a randomised, GENERIC landing page to /var/www/html so that any
#  direct-IP / unmatched-SNI probe sees an ordinary-looking website instead
#  of anything that reveals a proxy panel.
#
#  Design rule (kept from the original GFW4Fun/x-ui-pro approach, by intent):
#  the decoy is a *generic* template — it never impersonates a specific real
#  company or brand. That keeps the camouflage plausible without cloning
#  someone else's site. Credit: concept from GFW4Fun/x-ui-pro.
##########################################################################
set -e
WEBROOT="/var/www/html"
mkdir -p "$WEBROOT"

rand() { tr -dc 'a-z' </dev/urandom | head -c "$1"; }

# Pick one generic persona at random so repeat installs don't all look identical.
PERSONAS=("Cloud Storage" "Status Dashboard" "API Gateway" "Media Library" "Analytics Suite")
TAGLINES=("Fast, reliable infrastructure." "Everything in one place." "Built for scale."
          "Simple. Secure. Yours." "Your data, always available.")
i=$(( RANDOM % ${#PERSONAS[@]} ))
NAME="${PERSONAS[$i]}"
TAG="${TAGLINES[$(( RANDOM % ${#TAGLINES[@]} ))]}"
YEAR=$(date +%Y)
HUE=$(( RANDOM % 360 ))

cat > "$WEBROOT/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${NAME}</title>
<style>
  :root { --a: hsl(${HUE} 70% 55%); --b: hsl(${HUE} 60% 35%); }
  * { box-sizing: border-box; margin: 0; }
  body { font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    color: #1c2333; background: #f5f7fb; line-height: 1.55; }
  header { padding: 18px 6vw; display: flex; align-items: center; justify-content: space-between;
    border-bottom: 1px solid #e6eaf2; }
  .logo { font-weight: 800; font-size: 19px; color: var(--b); }
  nav a { color: #475067; text-decoration: none; margin-left: 22px; font-size: 14px; }
  .hero { padding: 12vh 6vw 10vh; max-width: 820px; }
  .hero h1 { font-size: clamp(30px, 6vw, 52px); letter-spacing: -.5px; }
  .hero p { font-size: 18px; color: #56607a; margin: 18px 0 28px; }
  .btn { display: inline-block; background: linear-gradient(135deg, var(--a), var(--b));
    color: #fff; padding: 13px 26px; border-radius: 10px; text-decoration: none; font-weight: 600; }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr));
    gap: 22px; padding: 0 6vw 12vh; max-width: 1100px; }
  .card { background: #fff; border: 1px solid #e6eaf2; border-radius: 14px; padding: 24px; }
  .card h3 { font-size: 17px; margin-bottom: 8px; }
  .card p { color: #56607a; font-size: 14px; }
  footer { border-top: 1px solid #e6eaf2; padding: 26px 6vw; color: #8a93a8; font-size: 13px; }
</style>
</head>
<body>
  <header>
    <div class="logo">${NAME}</div>
    <nav><a href="#">Product</a><a href="#">Docs</a><a href="#">Pricing</a><a href="#">Sign in</a></nav>
  </header>
  <section class="hero">
    <h1>${NAME}</h1>
    <p>${TAG} Get started in minutes with a workspace that grows with you.</p>
    <a class="btn" href="#">Get started</a>
  </section>
  <section class="grid">
    <div class="card"><h3>Reliable</h3><p>$(rand 5)-grade uptime with automated failover and backups.</p></div>
    <div class="card"><h3>Secure</h3><p>Encryption in transit and at rest, with granular access controls.</p></div>
    <div class="card"><h3>Simple</h3><p>A clean interface that stays out of your way so you can focus.</p></div>
  </section>
  <footer>© ${YEAR} ${NAME}. All rights reserved.</footer>
</body>
</html>
EOF

# A benign robots.txt completes the ordinary-site picture.
cat > "$WEBROOT/robots.txt" << 'EOF'
User-agent: *
Disallow:
EOF

echo "Decoy site generated at $WEBROOT (persona: ${NAME})"
