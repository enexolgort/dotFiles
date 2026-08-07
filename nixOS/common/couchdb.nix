# common/couchdb.nix — via the "Self-hosted LiveSync" community plugin,
# backed by CouchDB. Obsidian's official paid Sync service is NOT
# self-hostable; this is the community-standard alternative. Reachable
# only via your tailnet at http://<tailscale-ip>:5984
{
  config,
  pkgs,
  lib,
  vars,
  ...
}: {
  services.couchdb = {
    enable = vars.obsidianEnable;
    bindAddress = "0.0.0.0"; # legacy [httpd] section — CouchDB 3.x doesn't actually serve from here
    adminUser = vars.couchdbAdminUser;
    adminPass = vars.couchdbAdminPass; # CHANGE in vars.nix — see doc/secrets.md re: this option's real limitation
    extraConfig = {
      chttpd = {
        enable_cors = "true";
        bind_address = "0.0.0.0"; # the section CouchDB 3.x's real listener actually reads
      };
      cors = {
        origins = "app://obsidian.md, capacitor://localhost, http://localhost";
        credentials = "true";
        headers = "accept, authorization, content-type, origin, referer";
        methods = "GET,PUT,POST,HEAD,DELETE";
        max_age = "3600";
      };
    };
  };

  systemd.services.couchdb = {
    after = ["network-online.target"];
    wants = ["network-online.target"];
  };
}
