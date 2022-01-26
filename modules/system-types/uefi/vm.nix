{ config, pkgs, lib, ... }:

let
  # This particular VM module is only enabled for the uefi system type.
  enabled = config.mobile.system.type == "uefi";

  inherit (lib) mkAfter mkIf mkOption types;
  inherit (config.mobile) device hardware;
  inherit (config.mobile.boot) stage-1;
  inherit (config.mobile.outputs.uefi) disk-image;

  ram  = toString hardware.ram;
  xres = toString hardware.screen.width;
  yres = toString hardware.screen.height;
  fwd22_port = toString config.mobile.outputs.uefi.fwd22_port;
  fwd23_port = toString config.mobile.outputs.uefi.fwd23_port;
in
{
  options = {
    mobile = {
      outputs = {
        uefi = {
          vm = mkOption {
            type = types.package;
            description = ''
              Script to start a UEFI-based virtual machine.
            '';
            visible = false;
          };
          fwd22_port = mkOption {
            type = types.int;
            default = 2222;
            description = ''
              Host TCP port to forward VM's port 22 (usually, sshd).
            '';
          };
          fwd23_port = mkOption {
            type = types.int;
            default = 2223;
            description = ''
              Host TCP port to forward VM's port 23.
            '';
          };
        };
      };
    };
  };
  config = mkIf enabled {
    boot.kernelParams = mkAfter [
      "console=ttyS0"
    ];

    mobile.boot.stage-1.kernel.modules = [
      # Networking
      "e1000"

      # Input within X11
      "uinput" "evdev"

      # Video
      "bochs_drm"
    ];
    mobile.outputs.uefi = {
      vm = pkgs.writeShellScript "run-vm-${device.name}" ''
        ARGS=(
          -enable-kvm
          -bios   "${pkgs.OVMF.fd}/FV/OVMF.fd"
          -m      "${ram}M"
          -serial "mon:stdio"
          -drive  "file=${disk-image}/${disk-image.filename},format=raw,snapshot=on"

          -device "VGA,edid=on,xres=${xres},yres=${yres}"
          -device "usb-ehci"
          -device "usb-kbd"
          -device "usb-tablet"

          -device "e1000,netdev=net0"
          -netdev "user,id=net0,hostfwd=tcp::${fwd22_port}-:22,hostfwd=tcp::${fwd23_port}-:23,net=172.16.42.0/24,dhcpstart=172.16.42.1"

          -device "e1000,netdev=user.0"
          -netdev "user,id=user.0"
        )

        ${pkgs.qemu}/bin/qemu-system-${pkgs.targetPlatform.qemuArch} "''${ARGS[@]}" "''${@}"
      '';
    };
  };
}
