# Sets the guest display mode from the console session: set-resolution.ps1 <width> <height>
$src = @'
using System; using System.Runtime.InteropServices;
public static class R {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct DM { [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string n; public short sv,dv,sz,ex; public int fl; public int x,y,or,fo; public short col,dup,yr,tt,co; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string fn; public short lp; public int bpp,w,h,df,fq; public int a,b,c,d,e,f,g,h2; }
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern bool EnumDisplaySettingsW(string d,int i,ref DM m);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int ChangeDisplaySettingsW(ref DM m,int f);
  public static string Run(int w,int h){ DM m=new DM(); m.sz=(short)Marshal.SizeOf(typeof(DM)); EnumDisplaySettingsW(null,-1,ref m); string was=m.w+"x"+m.h; m.w=w; m.h=h; m.fl=0x180000; int r=ChangeDisplaySettingsW(ref m,1); DM n=new DM(); n.sz=m.sz; EnumDisplaySettingsW(null,-1,ref n); return "was="+was+" result="+r+" now="+n.w+"x"+n.h; }
}
'@
try { Add-Type -TypeDefinition $src; [R]::Run([int]$args[0],[int]$args[1]) | Set-Content C:\OEM\res.txt } catch { "failed: $_" | Set-Content C:\OEM\res.txt }
