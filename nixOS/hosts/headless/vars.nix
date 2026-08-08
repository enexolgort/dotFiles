{
  hostname = "headless";
  username = "enexolgort";
  gitEmail = "enexolgort@headless.local";
  targetType = "wsl";

  jellyfinEnable = false;
  obsidianEnable = true;
  gitServerEnable = true;
  aiEnable = false;
  sftpEnable = false;

  # obsidianEnable = true, so these need to actually be here.
  couchdbAdminUser = "admin";
  couchdbAdminPass = "changeme-couchdb"; # CHANGE THIS

  # gitServerEnable = true, so these need to actually be here.
  # NOTE: "admin" itself is a reserved username in Forgejo.
  gitAdminUser = "gituser";
  gitAdminPass = "changeme-git"; # CHANGE THIS

  backupEnable = false;

  projectRepos = [
    "https://github.com/enexolgort/transmission-API"
  ];
}
