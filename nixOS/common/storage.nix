# common/storage.nix — directory layout for everything under vars.mediaDir
# / sftpDir / projectsDir. Kept centralized here rather than split across
# each service's own file, since the directory structure itself is a
# cross-cutting concern shared by Jellyfin, Samba, SFTP, and backups —
# one place to see the whole layout at a glance.
{ config, pkgs, lib, vars, ... }:

{
  systemd.tmpfiles.rules =
    [
      # Media library. Jellyfin runs as the "jellyfin" user; "media" is a
      # dedicated shared group (see base.nix) that the admin user and
      # sftpuser are both members of, so they can actually write here too —
      # not the user's own primary group, which for a normal NixOS user is
      # just the generic "users" (gid 100), not a same-named group.
      "d ${vars.mediaDir} 0775 jellyfin media -"
      "d ${vars.mediaDir}/Movies 0775 jellyfin media -"
      "d ${vars.mediaDir}/Music 0775 jellyfin media -"
      "d ${vars.mediaDir}/Photo 0775 jellyfin media -"

      # Where install.sh clones your project repos. /data itself is
      # root-owned by default, so this needs an explicit rule rather than
      # relying on a plain mkdir. Group is "users" (gid 100) — the real
      # default group every normal NixOS user is actually in.
      "d ${vars.projectsDir} 0755 ${vars.username} users -"
    ]
    ++ lib.optionals vars.sftpEnable [
      # SFTP chroot root — must stay root:root (sshd's strict chroot
      # security check), actual writable content is the bind mount inside
      # it, see sftp.nix. vars.sftpDir only needs to exist on hosts where
      # sftpEnable is true — see hosts/defaults.nix.
      "d ${vars.sftpDir} 0755 root root -"
      "d ${vars.sftpDir}/upload 0755 root root -"
    ];
}
