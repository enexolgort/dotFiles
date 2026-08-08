# common/ai.nix — local LLM hosting. Off unless vars.aiEnable = true
# (currently just scrapy). Both services are confirmed real NixOS
# modules (not something built from scratch) — Ollama is the model
# runner, Open WebUI is the well-established ChatGPT-style frontend for
# it, specifically built to pair with Ollama.
#
# No firewall changes needed: trustedInterfaces (networking.nix) already
# covers these ports automatically, same as every other service here.
# Ollama itself listens on 11434, Open WebUI's frontend on 8080.
{ config, pkgs, lib, vars, ... }:

lib.mkIf vars.aiEnable {
  services.ollama = {
    enable = true;
    # CPU-only by default. If scrapy has a compatible GPU, override this
    # to "cuda" or "rocm" here for real acceleration — CPU inference
    # works but is slow for anything beyond small models.
    acceleration = false;
    loadModels = vars.aiModels; # auto-downloaded on rebuild, see hosts/scrapy/vars.nix
  };

  services.open-webui = {
    enable = true;
    # Defaults to 127.0.0.1-only otherwise — same class of bug we hit
    # with CouchDB earlier. NOT using host = ""; despite that being the
    # "bind all interfaces" convention some docs mention — there's a
    # known nixpkgs bug (NixOS/nixpkgs#378188) where the empty string
    # breaks shell quoting in the generated systemd unit and the service
    # fails to start entirely. An explicit "0.0.0.0" avoids that bug.
    host = "0.0.0.0";
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434/api";
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
    };
  };

  systemd.services.ollama = {
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
  };
  systemd.services.open-webui = {
    after = [ "network-online.target" "ollama.service" ];
    wants = [ "network-online.target" ];
  };
}
