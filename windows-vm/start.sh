#!/bin/zsh
# Runs the Windows 11 ARM guest on macOS QEMU with HVF.
#   ./start.sh install   first boot, with the install media attached
#   ./start.sh           normal boot
#   ./start.sh check     start paused, validate the config, then quit
# Sizing: RAM_SIZE=4G CPU_CORES=4 ./start.sh
set -eu
cd "${0:A:h}"
mode="${1:-run}"
mac=$(cat vm/windows.mac)
args=(
  -nodefaults
  -machine virt,secure=off,gic-version=max,msi=gicv2m
  -accel hvf
  -cpu host
  -smp "${CPU_CORES:-4}"
  -m "${RAM_SIZE:-4G}"
  -name Windows
  -device virtio-gpu-pci,xres=1920,yres=1080
  -device qemu-xhci,id=xhci,p2=7,p3=7
  -device usb-kbd
  -device usb-tablet
  -netdev "user,id=hostnet0,hostfwd=tcp:127.0.0.1:2222-:22,hostfwd=tcp:127.0.0.1:6911-:6911"
  -device "virtio-net-pci,id=net0,netdev=hostnet0,romfile=,mac=$mac"
  -object iothread,id=io2
  -drive file=vm/windows.qcow2,id=data3,format=qcow2,cache=writeback,discard=unmap,detect-zeroes=unmap,if=none
  -device virtio-scsi-pci,id=data3,bus=pcie.0,addr=0xa,iothread=io2
  -device scsi-hd,drive=data3,bus=data3.0,channel=0,scsi-id=0,lun=0,rotation_rate=1,bootindex=3
  -rtc base=localtime
  -drive file=/opt/homebrew/share/qemu/edk2-aarch64-code.fd,if=pflash,unit=0,format=raw,readonly=on
  -drive file=vm/efi-vars.fd,if=pflash,unit=1,format=raw
  -fw_cfg name=opt/org.tianocore/UninstallMemAttrProtocol,string=y
)
if [[ "$mode" == install || "$mode" == check ]]; then
  args+=(
    -drive file=iso/win11arm64.iso,id=boot,format=raw,cache=unsafe,readonly=on,media=cdrom,if=none
    -device usb-storage,drive=boot,bootindex=9,removable=on
    -drive file=vm/setup.img,id=setup,format=raw,cache=unsafe,media=disk,if=none
    -device usb-storage,drive=setup,removable=on
  )
fi
if [[ "$mode" == check ]]; then
  print quit | exec qemu-system-aarch64 "${args[@]}" -S -display none -monitor stdio
fi
exec nice -n 10 qemu-system-aarch64 "${args[@]}" \
  -display vnc=127.0.0.1:90 \
  -monitor unix:vm/monitor.sock,server=on,wait=off \
  -pidfile vm/qemu.pid -daemonize
