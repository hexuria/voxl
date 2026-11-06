# Calls the same DXGI path voxl uses, from the logged-in console session.
$src = @'
using System;
using System.Runtime.InteropServices;
public static class P {
  [DllImport("dxgi.dll")] static extern int CreateDXGIFactory1(ref Guid r, out IntPtr f);
  [DllImport("d3d11.dll")] static extern int D3D11CreateDevice(IntPtr a, int t, IntPtr s, uint fl, IntPtr lv, uint n, uint sdk, out IntPtr d, IntPtr got, out IntPtr c);
  delegate int Enum2(IntPtr self, uint i, out IntPtr o);
  delegate int QI(IntPtr self, ref Guid r, out IntPtr o);
  delegate int Dup(IntPtr self, IntPtr dev, out IntPtr o);
  delegate int Acq(IntPtr self, uint ms, IntPtr info, out IntPtr res);
  delegate int Rel(IntPtr self);
  delegate int Desc(IntPtr self, IntPtr d);
  static T V<T>(IntPtr o, int i) { IntPtr vt = Marshal.ReadIntPtr(o); return (T)(object)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vt, i * IntPtr.Size), typeof(T)); }
  public static string Run(string factoryIid, string output1Iid) {
    var log = new System.Text.StringBuilder();
    Guid fi = new Guid(factoryIid), oi = new Guid(output1Iid);
    IntPtr f; int hr = CreateDXGIFactory1(ref fi, out f);
    log.AppendLine("CreateDXGIFactory1 hr=0x" + hr.ToString("X8"));
    for (uint a = 0; ; a++) {
      IntPtr ad; hr = V<Enum2>(f, 12)(f, a, out ad);
      if (hr != 0) break;
      IntPtr d = Marshal.AllocHGlobal(512);
      V<Desc>(ad, 8)(ad, d);
      log.AppendLine("adapter " + a + ": " + Marshal.PtrToStringUni(d));
      for (uint o = 0; ; o++) {
        IntPtr op; hr = V<Enum2>(ad, 7)(ad, o, out op);
        if (hr != 0) break;
        V<Desc>(op, 7)(op, d);
        log.AppendLine("  output " + o + ": " + Marshal.PtrToStringUni(d) + " rect=" + Marshal.ReadInt32(d, 64) + "," + Marshal.ReadInt32(d, 68) + "," + Marshal.ReadInt32(d, 72) + "," + Marshal.ReadInt32(d, 76));
        IntPtr dev, ctx;
        hr = D3D11CreateDevice(ad, 0, IntPtr.Zero, 0x20, IntPtr.Zero, 0, 7, out dev, IntPtr.Zero, out ctx);
        log.AppendLine("  D3D11CreateDevice hr=0x" + hr.ToString("X8"));
        if (hr != 0) continue;
        IntPtr o1; hr = V<QI>(op, 0)(op, ref oi, out o1);
        log.AppendLine("  QI IDXGIOutput1 hr=0x" + hr.ToString("X8"));
        if (hr != 0) continue;
        IntPtr dup; hr = V<Dup>(o1, 22)(o1, dev, out dup);
        log.AppendLine("  DuplicateOutput hr=0x" + hr.ToString("X8"));
        if (hr != 0) continue;
        IntPtr info = Marshal.AllocHGlobal(256);
        int ok = 0, timeouts = 0, other = 0; int last = 0;
        for (int i = 0; i < 20; i++) {
          IntPtr res; hr = V<Acq>(dup, 8)(dup, 250, info, out res);
          if (hr == 0) { ok++; V<Rel>(res, 2)(res); V<Rel>(dup, 14)(dup); }
          else if (hr == unchecked((int)0x887A0027)) timeouts++;
          else { other++; last = hr; }
        }
        log.AppendLine("  AcquireNextFrame ok=" + ok + " timeouts=" + timeouts + " errors=" + other + " last=0x" + last.ToString("X8"));
      }
    }
    return log.ToString();
  }
}
'@
try {
  Add-Type -TypeDefinition $src
  $r = [P]::Run($args[0], $args[1])
} catch { $r = "probe failed: $_" }
"session=$([System.Diagnostics.Process]::GetCurrentProcess().SessionId) ptr=$([IntPtr]::Size)`n$r" | Set-Content C:\OEM\dda.txt
