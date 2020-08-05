{ config, pkgs, lib, ... }:
let
  c = import ./common_attr.nix {};
  # I'm leaving this commented to show multiples ways of how this
  # can be imported
  #c = pkgs.callPackage ./common_attr.nix {};
  #c = lib.recursiveUpdate (pkgs.callPackage ./common_attr.nix {})
  hostname = "stannis";
  net = {
    interface = {
      ip="192.168.1.160";
      name="wlan0";
      mac="08:11:96:a3:6b:cc";
    };
  };
  f = ''SUBSYSTEM=="net",ACTION=="add",DRIVERS=="?*",ATTR{type}=="1",'';
in
{
  networking.usePredictableInterfaceNames = true;
  services.udev.extraRules = ''
  ${f} ATTR{address}=="${net.interface.mac}", NAME="${net.interface.name}"
  '';

  imports = [ 
    /etc/nixos/hardware-configuration.nix
    ./common.nix
    ./beacon_prysm.nix
    (import ./uk_wifi.nix {
      config=config;
      interface=net.interface.name;
      ip=net.interface.ip;
    })
    (import ./wireguard.nix { config=config; hostname=hostname; })
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  environment.systemPackages = with pkgs; [
  ] ++ c.commonPackages ++ c.workPackages;

  services = {
    logind.lidSwitch = "ignore";
    xserver = {
      xkbOptions = "ctrl:nocaps,compose:ralt";
      libinput.enable = true;
    };
  };

  networking = {
    enableIPv6 = false;
    hostName = hostname;
    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [ 22 ];
    };
  };

  virtualisation.docker = {
    liveRestore = false;
    enable = true;
  };
}
