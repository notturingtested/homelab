{ config, lib, ... }:

{
  # Disko declarative disk layout
  # This wipes and partitions the drive on first install
  disko.devices = {
    disk = {
      main = {
        device = "/dev/sda";  # TODO: update per host (nvme0n1, sda, etc.)
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
