#!/usr/bin/env bash
set -euo pipefail

DEV_USER="sudhz"
DEVBOX_REPO="https://github.com/sudhz/devbox.git"
DEVBOX_DIR="/home/$DEV_USER/devbox"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this bootstrap as root."
  exit 1
fi

echo "==> Checking Ubuntu"
if ! grep -q 'Ubuntu 24.04' /etc/os-release; then
  echo "Warning: this setup was built for Ubuntu 24.04."
fi

echo "==> Installing bootstrap dependencies"
apt update
apt install -y \
  curl \
  git \
  gh \
  sudo \
  xz-utils \
  ca-certificates

echo "==> Configuring 2 GB swap"
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
fi

if ! swapon --show | grep -q '/swapfile'; then
  swapon /swapfile
fi

grep -q '^/swapfile ' /etc/fstab \
  || echo '/swapfile none swap sw 0 0' >> /etc/fstab

echo "==> Creating $DEV_USER"
if ! id "$DEV_USER" >/dev/null 2>&1; then
  adduser "$DEV_USER"
fi

usermod -aG sudo "$DEV_USER"

echo "==> Installing GitHub SSH keys"
install -d -m 700 -o "$DEV_USER" -g "$DEV_USER" "/home/$DEV_USER/.ssh"

curl -fsSL "https://github.com/$DEV_USER.keys" \
  > "/home/$DEV_USER/.ssh/authorized_keys"

chown "$DEV_USER:$DEV_USER" "/home/$DEV_USER/.ssh/authorized_keys"
chmod 600 "/home/$DEV_USER/.ssh/authorized_keys"

echo "==> Installing multi-user Nix"
if [ ! -x /nix/var/nix/profiles/default/bin/nix ]; then
  curl -L https://nixos.org/nix/install | sh -s -- --daemon
fi

mkdir -p /etc/nix

grep -q '^experimental-features' /etc/nix/nix.conf 2>/dev/null \
  || echo 'experimental-features = nix-command flakes' >> /etc/nix/nix.conf

grep -q '^auto-optimise-store' /etc/nix/nix.conf 2>/dev/null \
  || echo 'auto-optimise-store = true' >> /etc/nix/nix.conf

systemctl restart nix-daemon

echo "==> Cloning devbox configuration"
if [ ! -d "$DEVBOX_DIR/.git" ]; then
  sudo -u "$DEV_USER" git clone "$DEVBOX_REPO" "$DEVBOX_DIR"
else
  sudo -u "$DEV_USER" git -C "$DEVBOX_DIR" pull --ff-only
fi

echo
echo "==> GitHub login is required for this devbox"
sudo -iu "$DEV_USER" gh auth status >/dev/null 2>&1 || \
  sudo -iu "$DEV_USER" gh auth login

echo "==> Configuring Git identity from GitHub"
sudo -iu "$DEV_USER" bash <<'EOS'
git config --global user.name "$(gh api user --jq '.name // .login')"
git config --global user.email "$(
  gh api user --jq '(.id|tostring) + "+" + .login + "@users.noreply.github.com"'
)"
EOS

echo "==> Applying Home Manager configuration"
sudo -iu "$DEV_USER" bash -lc "
  nix run github:nix-community/home-manager/release-26.05 -- \
    switch --flake '$DEVBOX_DIR#sudhz'
"

echo
echo "Devbox bootstrap complete."
echo "Next login:"
echo "  ssh $DEV_USER@<server-ip>"
