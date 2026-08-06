{
  # ==== System ============================================================
  system = "x86_64-linux";      # aarch64-linux if on ARM
  hostname = "scrapy";
  timeZone = "Europe/Paris";
  locale = "en_US.UTF-8";
  keyMap = "us";                # e.g. "fr" for AZERTY on console

  # ==== Main user ==========================================================
  username = "enexolgort";
  initialPassword = "changeme"; # change on first login with: passwd <username>
  gitEmail = "enexolgort@scrapy.local";

  # ==== Storage paths ======================================================
  mediaDir = "/data/media";
  sftpDir = "/data/sftp";

  # ==== SFTP ===============================================================
  sftpPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... replace-with-your-key sftpuser@yourlaptop";

  # ==== CouchDB / Obsidian LiveSync =======================================
  couchdbAdminUser = "admin";
  couchdbAdminPass = "changeme-couchdb"; # plaintext in the Nix store — see README re: secrets

  # ==== Samba ==============================================================
  sambaWorkgroup = "WORKGROUP";
}