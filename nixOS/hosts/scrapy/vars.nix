{
  hostname = "scrapy";
  username = "enexolgort";
  gitEmail = "enexolgort@scrapy.local";
  targetType = "wsl";

  jellyfinEnable = false;
  obsidianEnable = false;
  gitServerEnable = false;
  aiEnable = true; # Ollama + Open WebUI — see common/ai.nix
  sftpEnable = false;

  backupEnable = false;

  projectRepos = [ ];
}
