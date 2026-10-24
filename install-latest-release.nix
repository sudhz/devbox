# install-latest-release OWNER/REPO ASSET DEST: install the latest release asset if it changed.
{ pkgs }:

pkgs.writeShellApplication {
  name = "install-latest-release";
  runtimeInputs = [ pkgs.gh pkgs.curl pkgs.jq pkgs.coreutils ];

  text = ''
    repo="$1"
    asset="$2"
    dest="$3"

    release="$(gh api "repos/$repo/releases/latest")"

    tag="$(jq -r '.tag_name' <<<"$release")"
    url="$(jq -r --arg asset "$asset" \
      '.assets[] | select(.name == $asset) | .browser_download_url' <<<"$release")"
    sha="$(jq -r --arg asset "$asset" \
      '.assets[] | select(.name == $asset) | .digest // empty | ltrimstr("sha256:")' <<<"$release")"

    if [ -z "$url" ] || [ -z "$sha" ]; then
      echo "Could not find $asset in the latest $repo release." >&2
      exit 1
    fi

    if [ -f "$dest" ] && [ "$(sha256sum "$dest" | cut -d ' ' -f 1)" = "$sha" ]; then
      echo "$asset $tag is already installed."
      exit 0
    fi

    echo "Installing $asset $tag"
    mkdir -p "$(dirname "$dest")"
    curl -fsSL --connect-timeout 10 --speed-limit 1024 --speed-time 30 \
      -o "$dest.download" "$url"

    if ! echo "$sha  $dest.download" | sha256sum --check --quiet; then
      rm -f "$dest.download"
      echo "Checksum verification failed for $asset." >&2
      exit 1
    fi

    chmod 755 "$dest.download"
    mv -f "$dest.download" "$dest"
  '';
}
