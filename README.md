# devbox

My reproducible VPS development environment.

Built for a fresh Ubuntu 24.04 x86_64 VPS. The setup uses Nix + Home Manager and includes my usual CLI tools, OMP, Herdr, Reviewr, and their tracked configuration.

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
- installing Herdr and Reviewr
- linking the tracked OMP and Herdr configuration

Complete the GitHub login when prompted.

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

After that, start Herdr and use OMP + Reviewr normally.
