{ pkgs, ... }:

{
  home.username = "sudhz";
  home.homeDirectory = "/home/sudhz";

  # Keep this at the version where this config was first created.
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    git
    gh
    curl
    wget
    jq
    ripgrep
    fd
    fzf
    tree
    htop
    unzip
    zip
  ];
}
