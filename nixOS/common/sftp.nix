# common/sftp.nix — dedicated, chrooted, tailnet-only upload user
# (separate from your normal admin account). Drops files straight into
# the media dir. Directory layout itself is in storage.nix.
{ config, pkgs, lib, vars, ... }:

{
  fileSystems."${vars.sftpDir}/upload" = {
    device = vars.mediaDir;
    options = [ "bind" ];
  };

  users.groups.sftponly = {};
  users.users.sftpuser = {
    isSystemUser = true;
    group = "sftponly";
    extraGroups = [ "sftponly" ];
    shell = "${pkgs.shadow}/bin/nologin";
    openssh.authorizedKeys.keys = [ vars.sftpPublicKey ];
  };

  services.openssh.extraConfig = ''
    Match Group sftponly
      ChrootDirectory ${vars.sftpDir}
      ForceCommand internal-sftp
      AllowTcpForwarding no
      X11Forwarding no
      PasswordAuthentication no
  '';

  # NOTE: Samba lives in configuration.nix (real-machine only), not here —
  # nmbd depends on UDP broadcast networking that WSL2's virtualized NAT
  # adapter doesn't support, which makes it crash outright on the WSL
  # target rather than just being unreachable.
}
