# Builds voxl natively for Windows ARM64 inside the guest, one stage at a time.
$log = 'C:\OEM\build.log'; $status = 'C:\OEM\build.status'
function Say($m) { "$(Get-Date -Format HH:mm:ss) $m" | Add-Content $log; $m | Set-Content $status }
function Refresh { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') + ';' + "$env:USERPROFILE\.cargo\bin" }
function Stage($name, [scriptblock]$body) {
  Say "START $name"
  & $body *>> $log
  if ($LASTEXITCODE -ne 0) { Say "FAILED $name exit=$LASTEXITCODE"; exit 1 }
  Refresh
  Say "OK $name"
}
$w = '--silent','--accept-source-agreements','--accept-package-agreements','--disable-interactivity'
Stage 'git'  { winget install --id Git.Git @w }
Stage 'node' { winget install --id OpenJS.NodeJS.LTS @w }
Stage 'llvm' { winget install --id LLVM.LLVM @w }
Stage 'vs-build-tools' { winget install --id Microsoft.VisualStudio.2022.BuildTools @w --override '--quiet --wait --norestart --nocache --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 --add Microsoft.VisualStudio.Component.Windows11SDK.26100 --includeRecommended' }
Stage 'rustup' { winget install --id Rustlang.Rustup @w }
Stage 'rust-toolchain' { rustup default stable; rustc -vV }
Stage 'esbuild' { npm install -g esbuild }
Stage 'vcpkg-clone' { if (-not (Test-Path C:\vcpkg)) { git clone --depth 1 https://github.com/microsoft/vcpkg C:\vcpkg } ; C:\vcpkg\bootstrap-vcpkg.bat -disableMetrics }
$env:VCPKG_ROOT = 'C:\vcpkg'; $env:VCPKG_MAX_CONCURRENCY = '2'
$env:VCPKGRS_TRIPLET = 'arm64-windows-static-md'
$env:LIBCLANG_PATH = 'C:\Program Files\LLVM\bin'
Stage 'vcpkg-libs' { C:\vcpkg\vcpkg.exe install x264 libyuv opus --triplet arm64-windows-static-md }
Stage 'voxl-clone' { if (-not (Test-Path C:\voxl)) { git clone --depth 1 --branch v0.3.3 https://github.com/tembo/voxl C:\voxl } }
Stage 'voxl-build' { Set-Location C:\voxl; cargo build --release --locked --jobs 2 }
Say 'DONE'
