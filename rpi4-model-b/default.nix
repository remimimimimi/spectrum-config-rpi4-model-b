# SPDX-FileCopyrightText: 2022 Unikie

{ config ? import ../../spectrum/nix/eval-config.nix { } }:
config.pkgs.callPackage
({ stdenvNoCC, writeText, util-linux, jq, mtools, raspberrypifw }:

  let
    inherit (config)
    ;
    uboot = config.pkgs.ubootRaspberryPi4_64bit;
    spectrum = import ../../spectrum/release/live { inherit (config) ; };
    kernel = spectrum.rootfs.kernel;

  in stdenvNoCC.mkDerivation {
    pname = "spectrum-live-rpi4-model-b.img";
    version = "0.1";

    unpackPhase = "true";

    nativeBuildInputs = [ util-linux jq mtools ];

    buildCommand = let
      rpiBootloaderCfg = writeText "config.txt" ''
        enable_uart=1
        arm_64bit=1
        kernel=u-boot.bin
      '';
      bootCmd = writeText "boot_cmd.txt" ''
        fatload mmc 0:1 \''${kernel_addr_r} Image
        setenv bootargs "console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rw rootwait init=/bin/sh"
        booti \''${kernel_addr_r} - \''${fdt_addr}
      '';
    in ''
      install -m 0644 ${spectrum} $pname
      # dd if=/dev/zero bs=1M count=6 >> $pname
      # partnum=$(sfdisk --json $pname | grep "node" | wc -l)
      # while [ $partnum -gt 0 ]; do
      #   echo '+6M,' | sfdisk --move-data $pname -N $partnum
      #   partnum=$((partnum-1))
      # done
      # dd if=${uboot}/u-boot.bin of=$pname bs=1k seek=32 conv=notrunc
      IMG=$pname
      ESP_OFFSET=$(sfdisk --json $IMG | jq -r '
        # Partition type GUID identifying EFI System Partitions
        def ESP_GUID: "C12A7328-F81F-11D2-BA4B-00A0C93EC93B";
        .partitiontable |
        .sectorsize * (.partitions[] | select(.type == ESP_GUID) | .start)
      ')
      mcopy -no -i $pname@@$ESP_OFFSET ${raspberrypifw}/share/raspberrypi/boot/{bootcode.bin,start4.elf} ::/
      mcopy -no -i $pname@@$ESP_OFFSET ${uboot}/u-boot.bin ::/
      mcopy -no -i $pname@@$ESP_OFFSET ${rpiBootloaderCfg} ::/config.txt
      mcopy -no -i $pname@@$ESP_OFFSET ${bootCmd} ::/boot_cmd.txt
      mcopy -no -i $pname@@$ESP_OFFSET ${kernel}/dtbs/broadcom/bcm2711-rpi-4-b.dtb ::/spectrum
      mdir -i $pname@@$ESP_OFFSET ::/
      mv $pname $out
      # cp ${spectrum} $out
    '';
    # install -m 0644 ${spectrum} $pname
    # dd if=/dev/zero bs=1M count=6 >> $pname
    # partnum=$(sfdisk --json $pname | grep "node" | wc -l)
    # while [ $partnum -gt 0 ]; do
    #   echo '+6M,' | sfdisk --move-data $pname -N $partnum
    #   partnum=$((partnum-1))
    # done
    # dd if=${uboot}/u-boot.bin of=$pname bs=1k seek=32 conv=notrunc
    # IMG=$pname
    # ESP_OFFSET=$(sfdisk --json $IMG | jq -r '
    #   # Partition type GUID identifying EFI System Partitions
    #   def ESP_GUID: "C12A7328-F81F-11D2-BA4B-00A0C93EC93B";
    #   .partitiontable |
    #   .sectorsize * (.partitions[] | select(.type == ESP_GUID) | .start)
    # ')
    # mcopy -no -i $pname@@$ESP_OFFSET ${kernel}/dtbs/freescale/imx8qm-mek-hdmi.dtb ::/
    # mcopy -no -i $pname@@$ESP_OFFSET ${config.pkgs.imx-firmware}/hdmitxfw.bin ::/
    # mv $pname $out
  }) { }
