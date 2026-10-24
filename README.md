# devbox

My reproducible VPS development environment.

Built for a fresh Ubuntu 24.04 x86_64 VPS. The setup uses Nix + Home Manager and includes my usual CLI tools (including FFmpeg), OMP, an Orca server reachable through a Cloudflare Tunnel, and their tracked configuration.

## Fresh VPS setup

SSH into the new VPS as root:

```bash
ssh root@<server-ip>
```

Run the bootstrap script:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sudhz/devbox/main/bootstrap.sh)
```

The script handles the rest, including:

- creating the `sudhz` user
- configuring swap
- installing Nix
- cloning this repo
- applying the Home Manager config
- installing OMP
- installing the Orca server and its Cloudflare Tunnel
- allowing only SSH through the firewall
- linking the tracked OMP configuration

Complete the GitHub and Cloudflare logins when prompted.

The Orca server is published at `orca.sudhz.dpdns.org`; to change it, edit `ORCA_HOST` at the top of `orca/setup.sh`.

Once bootstrap finishes, reconnect:

```bash
ssh sudhz@<server-ip>
```

Then start OMP:

```bash
omp
```

Log in to the providers you use.

OMP credentials and runtime state are intentionally not stored in this repo.

If GitHub access is needed from OMP, set the GitHub token in the environment as usual.

After that, use OMP from Orca terminals.

## Orca

`orca/setup.sh` installs the Orca server (`orca-serve` user service) and its Cloudflare Tunnel (`cloudflared-tunnel`); bootstrap runs it. When the Mac shows **Manual update** for the server, update it with:

```bash
~/devbox/orca/setup.sh
```

Open terminals survive the restart.

On a fresh install, the script ends by printing a pairing link for the Mac (paste it into **Settings → Remote Orca Servers → Add Server**) and a QR code for Orca Mobile. To pair another device later, run `~/devbox/orca/setup.sh --pair`.

## Updating an existing devbox

After changing this repo, apply its Home Manager configuration as `sudhz`:

```bash
home-manager switch --flake ~/devbox#sudhz
```
