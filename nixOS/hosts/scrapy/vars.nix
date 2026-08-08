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
  n8nEnable = true;

  # Smallest usable model, given weak/CPU-only hardware — auto-downloaded
  # on rebuild. Add more entries here later once you want to try bigger
  # ones (e.g. "llama3.2:1b").
  aiModels = [ "qwen2.5:0.5b" ];

  backupEnable = false;

  projectRepos = [ ];
}
