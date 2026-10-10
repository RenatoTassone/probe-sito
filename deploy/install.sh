#!/usr/bin/env bash
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Eseguire con sudo."; exit 1; }
src="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$src/site/index.html" ]
nginx -t
cfg=/etc/nginx/sites-available/probe-sito
enabled=/etc/nginx/sites-enabled/probe-sito
conflicts="$(grep -RlE 'server_name.*[[:space:]]www[.]probe[.]srl([[:space:];]|$)' /etc/nginx/sites-enabled 2>/dev/null | grep -vFx "$enabled" || true)"
[ -z "$conflicts" ] || { echo "Dominio gia configurato: $conflicts"; exit 1; }
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
base=/var/www/probe-sito
release="$base/releases/$stamp"
install -d -m 755 "$release"
cp -a "$src/site/." "$release/"
find "$release" -type d -exec chmod 755 {} +
find "$release" -type f -exec chmod 644 {} +
old="$(readlink "$base/current" || true)"
backup="/etc/nginx/probe-sito-backup-$stamp"
install -d -m 700 "$backup"
[ ! -e "$cfg" ] || cp -a "$cfg" "$backup/config"
[ ! -e "$enabled" ] || cp -a "$enabled" "$backup/enabled"
rollback() {
  if [ -e "$backup/config" ]; then cp -a "$backup/config" "$cfg"; else rm -f "$cfg"; fi
  if [ -e "$backup/enabled" ]; then rm -f "$enabled"; cp -a "$backup/enabled" "$enabled"; else rm -f "$enabled"; fi
  if [ -n "$old" ]; then ln -sfn "$old" "$base/current"; else rm -f "$base/current"; fi
}
[ ! -e "$base/current" ] || [ -L "$base/current" ] || { echo "current non e un collegamento: interruzione."; exit 1; }
ln -sfn "$release" "$base/current"
if [ ! -e "$cfg" ]; then install -m 644 "$src/deploy/probe-sito.conf" "$cfg"; fi
ln -sfn "$cfg" "$enabled"
if ! nginx -t; then rollback; exit 1; fi
if ! systemctl reload nginx; then rollback; nginx -t && systemctl reload nginx; exit 1; fi
curl --fail --silent --show-error -I -H 'Host: www.probe.srl' http://127.0.0.1/
curl --fail --silent --show-error -I -H 'Host: www.probe.srl' http://127.0.0.1/assets/probe-logo.png
echo "SITO INSTALLATO. DNS e HTTPS restano da completare."
