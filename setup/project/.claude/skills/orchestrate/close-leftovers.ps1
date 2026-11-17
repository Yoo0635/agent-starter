# 오케스트레이션이 끝난 뒤 이 worktree 에서 띄우고 남은 bash·powershell·tail·sleep 과 그 conhost 를 닫는다(ORCH-057).
# 쓰기: powershell -NoProfile -File <레포 루트>/.claude/skills/orchestrate/close-leftovers.ps1 <통합 worktree> [-List]
#   -List 는 닫지 않고 고른 것만 보인다.
# 고르는 것: 이름이 bash·powershell·tail·sleep 이고
#   ① 이 스크립트를 부른 claude 세션의 자식·손자이거나
#   ② 작업 폴더가 <통합 worktree>(그 아래, 또는 이름 뒤에 `-` 가 붙은 형제 worktree) 이면서 부모가 죽은 것.
#   다른 claude·codex·Orca 터미널 같은 살아 있는 프로세스 아래 있으면 남의 것이라 닫지 않는다. 부른 명령(조상 줄과 그 자식)도 닫지 않는다.
#   conhost 는 닫는 프로세스의 자식인 것만 닫는다. java·node 같은 다른 이름은 건드리지 않는다(Gradle 데몬은 다른 빌드가 쓸 수 있다).
#   PowerShell 5.1 이 한글을 읽게 이 파일은 BOM 있는 UTF-8 로 둔다.
param([Parameter(Mandatory = $true)][string]$Worktree, [switch]$List)
[Console]::OutputEncoding = [Text.Encoding]::UTF8

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Cwd {
  [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(int a, bool i, int pid);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll")] static extern bool ReadProcessMemory(IntPtr h, IntPtr addr, byte[] buf, int size, out IntPtr read);
  [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr h, int cls, IntPtr[] info, int len, out int ret);
  static IntPtr Ptr(IntPtr h, IntPtr addr) { var b = new byte[8]; IntPtr r; if (!ReadProcessMemory(h, addr, b, 8, out r)) return IntPtr.Zero; return (IntPtr)BitConverter.ToInt64(b, 0); }
  // PEB 의 ProcessParameters.CurrentDirectory 를 읽는다(64비트 프로세스)
  public static string Get(int pid) {
    IntPtr h = OpenProcess(0x0410, false, pid);
    if (h == IntPtr.Zero) return null;
    try {
      var pbi = new IntPtr[6]; int ret;
      if (NtQueryInformationProcess(h, 0, pbi, 48, out ret) != 0) return null;
      IntPtr pp = Ptr(h, pbi[1] + 0x20);
      if (pp == IntPtr.Zero) return null;
      var u = new byte[16]; IntPtr r;
      if (!ReadProcessMemory(h, pp + 0x38, u, 16, out r)) return null;
      var s = new byte[BitConverter.ToUInt16(u, 0)];
      if (!ReadProcessMemory(h, (IntPtr)BitConverter.ToInt64(u, 8), s, s.Length, out r)) return null;
      return System.Text.Encoding.Unicode.GetString(s);
    } finally { CloseHandle(h); }
  }
}
'@

# /c/... 꼴도 받는다
if ($Worktree -match '^/([a-zA-Z])/(.*)$') { $Worktree = $matches[1] + ':\' + $matches[2] }
$root = [IO.Path]::GetFullPath($Worktree).TrimEnd('\').ToLower()
$targets = 'bash.exe', 'powershell.exe', 'tail.exe', 'sleep.exe'

$all = Get-CimInstance Win32_Process
$by = @{}; $all | ForEach-Object { $by[[int]$_.ProcessId] = $_ }
# 부모 pid 가 다시 쓰였으면 부모가 자식보다 늦게 생겼다. 그런 부모는 죽은 것으로 본다
function Parent($p) {
	$q = $by[[int]$p.ParentProcessId]
	if ($q -and $q.CreationDate -le $p.CreationDate -and $q.ProcessId -ne $p.ProcessId) { $q } else { $null }
}

# 부른 쪽 조상 줄과 그 끝의 claude 세션
$chain = @{}; $me = $null; $p = $by[$PID]; $since = $null
while ($p) {
	$chain[[int]$p.ProcessId] = 1
	if ($p.Name -eq 'claude.exe') { $me = [int]$p.ProcessId; break }
	$since = $p.CreationDate
	$p = Parent $p
}

function Mine($p) {
	$cwd = [Cwd]::Get([int]$p.ProcessId)
	$inTree = $false
	if ($cwd) {
		$c = $cwd.TrimEnd('\').ToLower()
		$inTree = $c -eq $root -or $c.StartsWith($root + '\') -or $c.StartsWith($root + '-')
	}
	$q = $p
	while ($true) {
		$q = Parent $q
		if (-not $q) { return $inTree }                        # 부모가 죽은 고아
		if ([int]$q.ProcessId -eq $me) { return $true }       # 이 세션이 띄운 것
		if ($chain[[int]$q.ProcessId]) { return $false }      # 이 스크립트를 부른 명령의 일부(파이프의 tail 등)
		if ($targets -notcontains $q.Name) { return $false }  # 남의 프로세스 아래
	}
}

$kill = @{}
foreach ($p in $all) {
	$id = [int]$p.ProcessId
	# 부른 명령이 시작된 뒤 생긴 것은 그 명령의 일부다. 파이프의 tail 은 MSYS 에서 부모가 먼저 끝나 고아로 보인다
	if ($p.CreationDate -ge $since) { continue }
	if ($targets -contains $p.Name -and -not $chain[$id] -and (Mine $p)) { $kill[$id] = $p }
}
foreach ($p in $all) {
	if ($p.Name -eq 'conhost.exe' -and $kill[[int]$p.ParentProcessId] -and (Parent $p)) { $kill[[int]$p.ProcessId] = $p }
}

foreach ($p in $kill.Values) {
	$cmd = ($p.CommandLine + '') -replace '\s+', ' '
	if ($cmd.Length -gt 120) { $cmd = $cmd.Substring(0, 120) }
	'{0,6} {1,-15} {2}' -f $p.ProcessId, $p.Name, $cmd
	if (-not $List) { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
}
$sum = ($kill.Values | Group-Object Name | ForEach-Object { '{0} {1}' -f ($_.Name -replace '\.exe$'), $_.Count }) -join ', '
if (-not $sum) { $sum = '없음' }
'{0}: {1}' -f $(if ($List) { '닫을 것' } else { '닫음' }), $sum
