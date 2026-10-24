# OMP: tracked config, the latest release binary, and the pi-intercom plugin.
{ pkgs, lib, config, ... }:

let
  installLatestRelease = import ../install-latest-release.nix { inherit pkgs; };
in
{
  # Credentials and runtime state remain local in ~/.omp/agent.
  home.file.".omp/agent/config.yml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/devbox/omp/config.yml";

  home.file.".omp/agent/mcp.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/devbox/omp/mcp.json";

  home.activation.installLatestOmp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.getExe installLatestRelease} can1357/oh-my-pi omp-linux-x64 "$HOME/.local/bin/omp"
  '';

  home.activation.installLatestPiIntercom = lib.hm.dag.entryAfter [ "installLatestOmp" ] ''
    PATH="${pkgs.bun}/bin:$PATH" "$HOME/.local/bin/omp" install pi-intercom
  '';
}
