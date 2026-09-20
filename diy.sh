#!/bin/bash
# Default IP set to 192.168.31.1 (match current LAN network)
sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate

# ---------------------------------------------------------------------------
# Nikki: ship the official apk feed key and enable weekly auto-update.
#
# OpenWrt 25.12 uses apk (not opkg). Nikki publishes a signed apk feed at
#   https://nikkinikki.pages.dev/<branch>/<arch>/nikki
# so the stack can be upgraded with plain `apk upgrade`.
# ---------------------------------------------------------------------------
BASE=package/base-files/files
NIKKI_REPO="https://nikkinikki.pages.dev"
NIKKI_FEED="$NIKKI_REPO/openwrt-25.12/x86_64/nikki/packages.adb"

# 1) Trust key for Nikki's feed (apk rejects the index without it)
mkdir -p "$BASE/etc/apk/keys"
wget -q -O "$BASE/etc/apk/keys/nikki.pem" "$NIKKI_REPO/public-key.pem"

# 2) Helper that updates only the Nikki stack (never the whole system)
mkdir -p "$BASE/usr/bin"
cat > "$BASE/usr/bin/nikki-update" <<'EOF'
#!/bin/sh
# Update the Nikki stack from its official apk feed.
exec >/tmp/nikki-update.log 2>&1
echo "=== $(date) ==="
apk update
apk upgrade --no-interactive nikki luci-app-nikki luci-i18n-nikki-zh-cn mihomo-meta
echo "exit=$?"
EOF
chmod +x "$BASE/usr/bin/nikki-update"

# 3) First-boot setup: register the feed, drop the dangling distfeeds entry,
#    and schedule the weekly update.
mkdir -p "$BASE/etc/uci-defaults"
cat > "$BASE/etc/uci-defaults/99-nikki-feed" <<'EOF'
#!/bin/sh

# register the official Nikki feed (append, never overwrite)
grep -q 'nikkinikki.pages.dev' /etc/apk/repositories.d/customfeeds.list 2>/dev/null || \
	echo 'https://nikkinikki.pages.dev/openwrt-25.12/x86_64/nikki/packages.adb' \
		>> /etc/apk/repositories.d/customfeeds.list

# the build adds a dangling "nikki" entry to distfeeds.list (404 upstream); drop it
[ -f /etc/apk/repositories.d/distfeeds.list ] && \
	sed -i '\#/packages/x86_64/nikki/packages\.adb#d' /etc/apk/repositories.d/distfeeds.list

# weekly auto-update of the Nikki stack (Sunday 04:17)
touch /etc/crontabs/root
grep -q 'nikki-update' /etc/crontabs/root || \
	echo '17 4 * * 0 /usr/bin/nikki-update' >> /etc/crontabs/root
/etc/init.d/cron restart >/dev/null 2>&1

exit 0
EOF
chmod +x "$BASE/etc/uci-defaults/99-nikki-feed"
