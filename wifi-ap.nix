{ lib, pkgs, antenna, ... }:
let
  secrets = import <secrets>;
  ipAddress = "10.0.0.1";
  prefixLength = 24;
  servedAddressRange = "10.0.0.2,10.0.0.50,12h";
  ssid = "kerbal_optout_nomap";
  password = secrets."uk-wifi".pw;
  repeaterBSSID = "ac:84:c6:b1:ee:d7";
in {

  networking.firewall = {
    trustedInterfaces = [ 
      #embeded.name
      antenna.name
    ];
    extraCommands = ''
      iptables -t nat -A POSTROUTING -o ${antenna.name} -j MASQUERADE
    '';
  };

  networking.networkmanager.unmanaged = [ 
    #embeded.name
    antenna.name
  ];
  networking.interfaces."${antenna.name}".ipv4.addresses = [{
    address = ipAddress;
    prefixLength = prefixLength;
  }];

  networking = {
    wireless.networks."EE-Hub-9iPp" = {
    # This doesn't work for some reason and causes wpa to fail
    # to associate with the router ap
    #extraConfig = ''
    #  bssid_blacklist=${repeaterBSSID}
    #'';
    };
  };

   
  boot.kernel.sysctl = {
    #"net.ipv4.conf.${embeded.name}.forwarding" = true;
    "net.ipv4.conf.${antenna.name}.forwarding" = true;
  };

  systemd.services.check-ap = {
    description = "Reboots computer if the ${antenna.name} is not correct";
    wantedBy = [ "multi-user.targer" ];
    after = [ "hostapd.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.bash}/bin/bash ${pkgs.writeText "check-wifi.sh" ''
              wifi=$(${pkgs.coreutils}/bin/cat /sys/class/net/${antenna.name}/address)
              echo "Found MAC $wifi for ${antenna.name}"
              if [[ "$wifi" != "${antenna.mac}" ]]; then
                 echo "rebooting..."
                 ${pkgs.systemd}/bin/systemctl reboot
              fi
          ''}";
      Type = "oneshot";
      Restart = "no";
    };
  };

  systemd.services.hostapd = {
    description = "Hostapd";
    path = [ pkgs.hostapd ];
    wantedBy = [ "network.target" ];
    after = [
      "${antenna.name}-cfg.service"
      "nat.service"
      "bind.service"
      "dhcpd.service"
      "sys-subsystem-net-devices-${antenna.name}.service"
    ];
    serviceConfig = {
      ExecStart = "${pkgs.hostapd}/bin/hostapd -d ${
        pkgs.writeText "hostapd.conf" ''
          interface=${antenna.name}
          driver=nl80211
          ssid=${ssid}
          hw_mode=g
          channel=1
          ieee80211n=1
          wmm_enabled=1
          ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
          macaddr_acl=0
          auth_algs=1
          ignore_broadcast_ssid=0
          wpa=2
          wpa_key_mgmt=WPA-PSK
          wpa_passphrase=${password}
          rsn_pairwise=CCMP
        ''
      }";
      Restart = "always";
    };
  };

  # this enabled systemd-resolved which conflicts with dnsmasq on port 53
  systemd.network.enable = false; 
  services.dnsmasq = {
    enable = true;
    extraConfig = ''
      interface=${antenna.name}
      listen-address=${ipAddress}
      dhcp-range=${servedAddressRange}
    '';
  };
  networking.usePredictableInterfaceNames = true;
}
