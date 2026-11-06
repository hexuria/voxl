$src = @'
using System; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class M {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public struct DM { [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string n; public short sv,dv,sz,ex; public int fl; public int x,y,or,fo; public short col,dup,yr,tt,co; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string fn; public short lp; public int bpp,w,h,df,fq; public int a,b,c,d,e,f,g,h2; }
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern bool EnumDisplaySettingsW(string d,int i,ref DM m);
  public static string Run(){ var s=new SortedSet<string>(); DM m=new DM(); m.sz=(short)Marshal.SizeOf(typeof(DM)); for(int i=0;EnumDisplaySettingsW(null,i,ref m);i++){ s.Add(m.w+"x"+m.h+"@"+m.fq+" "+m.bpp+"bpp"); } return string.Join("\n",s); }
}
'@
try { Add-Type -TypeDefinition $src; [M]::Run() | Set-Content C:\OEM\modes.txt } catch { "probe failed: $_" | Set-Content C:\OEM\modes.txt }
