# common/storage.nix — directory layout for everything under vars.mediaDir
# / sftpDir / projectsDir. Kept centralized here rather than split across
# each service's own file, since the directory structure itself is a
# cross-cutting concern shared by Jellyfin, Samba, SFTP, and backups —
# one place to see the whole layout at a glance.
{ config, pkgs, lib, vars, ... }:

{
  systemd.tmpfiles.rules = [
    # Media library. Jellyfin runs as the "jellyfin" user/group.
    "d ${vars.mediaDir} 0775 jellyfin ${vars.username} -"
    "d ${vars.mediaDir}/movies 0775 jellyfin ${vars.username} -"
    "d ${vars.mediaDir}/shows 0775 jellyfin ${vars.username} -"
    "d ${vars.mediaDir}/music 0775 jellyfin ${vars.username} -"

    # SFTP chroot root — must stay root:root (sshd's strict chroot
    # security check), actual writable content is the bind mount inside
    # it, see sftp.nix.
    "d ${vars.sftpDir} 0755 root root -"
    "d ${vars.sftpDir}/upload 0755 root root -"

    # Where install.sh clones your project repos. /data itself is
    # root-owned by default, so this needs an explicit rule rather than
    # relying on a plain mkdir.
    "d ${vars.projectsDir} 0755 ${vars.username} ${vars.username} -"
  ];
}
