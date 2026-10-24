#!/usr/bin/env bash
# Install or update the Orca server and its Cloudflare Tunnel. Safe to re-run.
# Prints pairing links on a fresh install, or any time with --pair.
set -euo pipefail

ORCA_HOST="orca.sudhz.dpdns.org"
TUNNEL_NAME="devbox"

DIR="$(cd "$(dirname "$0")" && pwd)"
APPIMAGE="$HOME/.local/share/orca/orca-linux.AppImage"
TOKEN="$HOME/.cloudflared/orca.token"
UNITS="$HOME/.config/systemd/user"
DATA="$HOME/.config/orca"

[ -d "$DATA" ] && fresh=false || fresh=true

# Run the server in the foreground just long enough to print a pairing offer.
pairing_offer() {
  local log pid
  log="$(mktemp)"
  (umask 022 && exec setsid env ORCA_USER_DATA_PATH="$DATA" "$APPIMAGE" serve --port 6769 \
    --pairing-address "wss://$ORCA_HOST" "$@" >"$log" 2>&1) &
  pid=$!
  for _ in $(seq 120); do
    grep -q '^Pairing \(URL\|unavailable\):' "$log" && break
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  kill -- -"$pid" 2>/dev/null || true
  wait "$pid" || true
  for _ in $(seq 30); do
    ss -Hltn 'sport = :6769' | grep -q . || break
    sleep 1
  done
  if ! grep -q '^Pairing URL:' "$log"; then
    cat "$log" >&2
    rm -f "$log"
    return 1
  fi
  cat "$log"
  rm -f "$log"
}

echo "==> Checking the latest Orca release"

release="$(gh api repos/stablyai/orca/releases/latest)"
tag="$(jq -r '.tag_name' <<<"$release")"
sha="$(jq -r '.assets[] | select(.name == "orca-linux.AppImage") | .digest // empty | ltrimstr("sha256:")' <<<"$release")"

if [ -z "$sha" ]; then
  echo "Could not find the Orca AppImage in release $tag." >&2
  exit 1
fi

if [ -f "$APPIMAGE" ] && [ "$(sha256sum "$APPIMAGE" | cut -d ' ' -f 1)" = "$sha" ]; then
  echo "Orca $tag is already installed."
else
  echo "Installing Orca $tag"
  mkdir -p "$(dirname "$APPIMAGE")"
  curl -fSL --progress-bar -o "$APPIMAGE.download" \
    "https://github.com/stablyai/orca/releases/download/$tag/orca-linux.AppImage"
  echo "$sha  $APPIMAGE.download" | sha256sum --check --quiet
  chmod 755 "$APPIMAGE.download"
  # Renaming works even while Orca is running.
  mv -f "$APPIMAGE.download" "$APPIMAGE"
fi

echo "==> Connecting the Cloudflare Tunnel"

[ -f "$HOME/.cloudflared/cert.pem" ] || cloudflared tunnel login

cloudflared tunnel token "$TUNNEL_NAME" >/dev/null 2>&1 \
  || cloudflared tunnel create "$TUNNEL_NAME"

cloudflared tunnel route dns --overwrite-dns "$TUNNEL_NAME" "$ORCA_HOST"

token="$(cloudflared tunnel token "$TUNNEL_NAME")"
(umask 077 && echo "$token" > "$TOKEN")

echo "==> Installing the Orca and tunnel services"

mkdir -p "$UNITS"
ln -sf "$DIR/services/orca-serve.service" "$DIR/services/cloudflared-tunnel.service" "$UNITS/"

systemctl --user daemon-reload
systemctl --user enable orca-serve.service cloudflared-tunnel.service
systemctl --user restart orca-serve.service cloudflared-tunnel.service

echo "Orca $tag is running at wss://$ORCA_HOST"

if [ "$fresh" = true ] || [ "${1:-}" = "--pair" ]; then
  systemctl --user stop orca-serve.service
  trap 'systemctl --user start orca-serve.service' EXIT

  echo
  echo "==> Mac: paste this link into Settings → Remote Orca Servers → Add Server"
  pairing_offer | grep '^Pairing URL:'

  echo
  echo "==> Phone: scan this QR code in Orca Mobile → Pair"
  pairing_offer --mobile-pairing | sed -n '/QR:/,/^Pairing URL:/p'
fi
