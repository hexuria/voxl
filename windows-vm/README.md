# Windows test VM on Apple Silicon

Runs Windows 11 ARM on macOS with QEMU and HVF, viewed in the browser through voxl.

Docker Desktop has no `/dev/kvm` on an M1, so dockur can only emulate in software there. dockur is used just to build the unattended install image. QEMU on macOS then runs it.

## Rebuild from nothing

Needs Docker Desktop and `brew install qemu`. Run from this folder.

1. Create the folders and the guest SSH key:

   ```sh
   mkdir -p iso logs ssh vm
   ssh-keygen -q -t ed25519 -N '' -C windows-vm -f ssh/id_ed25519
   cp ssh/id_ed25519.pub oem/authorized_keys
   ```

2. Build the install image. `compose.prep.yml` expects `iso/win11arm64.iso`. To download one instead, remove that volume line and add `VERSION: "11"` under `environment`.

   ```sh
   docker compose -f compose.prep.yml up -d
   docker logs -f windows-prep
   ```

3. When the log says `Booting`, stop the container, or it starts a very slow software install. Then copy the files out and create the disk:

   ```sh
   docker stop windows-prep
   for f in setup.img windows.mac; do docker cp "windows-prep:/storage/$f" "vm/$f"; done
   cp /opt/homebrew/share/qemu/edk2-arm-vars.fd vm/efi-vars.fd
   qemu-img create -f qcow2 -o lazy_refcounts=on vm/windows.qcow2 96G
   ```

4. Install Windows. Press Enter at the boot prompt, through VNC on `127.0.0.1:5990` or with `sendkey ret` on `vm/monitor.sock`. Stop sending keys once Setup starts, because Cancel has focus there.

   ```sh
   ./start.sh install
   ```

5. Install voxl once `./ssh.sh 'echo ok'` works:

   ```sh
   (umask 077; openssl rand -hex 16 > vm/voxl.password)
   tools/deploy-voxl.sh arm64
   open "http://localhost:6911/?token=$(cat vm/voxl.password)"
   ```

After that, `./start.sh` boots normally and voxl starts at login.

## What will catch you out

- **Firmware:** dockur's `windows.rom` hangs under HVF. `start.sh` uses Homebrew's EDK2 firmware.
- **Storage:** dockur's `/storage` must be a named volume. A macOS bind mount can't delete its read-only driver folders.
- **Display:** `ramfb` gives Windows only 800x600. `virtio-gpu-pci` uses the `viogpudo` driver, which dockur's image installs. To change resolution, copy `tools/set-resolution.ps1` to `C:\OEM\` and run it as an Interactive scheduled task.
- **Console session:** screen capture fails from SSH. Run anything that needs the desktop as an Interactive scheduled task.
- **voxl console:** start voxl through `conhost.exe --headless`, or it leaves a window that kills voxl when closed.
- **Build artifacts:** GitHub keeps them for about 90 days. If `deploy-voxl.sh` finds none, push to this branch to rebuild them.
- **x64 apps:** they run emulated on Windows ARM, so this is not proof for real x64 hardware.

## Files

| File | Purpose |
| --- | --- |
| `start.sh` | Boots the guest; `RAM_SIZE` and `CPU_CORES` set its size |
| `ssh.sh` | Runs a command in the guest |
| `guard.sh` | Pauses the guest under heavy host load or low memory |
| `compose.prep.yml` | Builds the install image with dockur |
| `oem/` | First-login setup: SSH, firewall, no sleep |
| `tools/deploy-voxl.sh` | Installs and starts voxl in the guest |
| `tools/set-resolution.ps1` | Changes the guest resolution |
| `tools/dda-probe.ps1` | Tests the capture path voxl depends on |
| `tools/build-voxl.ps1` | Builds voxl inside the guest; slower than the GitHub build |
