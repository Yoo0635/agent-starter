# SessionStart hook: Claude 데스크톱 터미널 패널이 띄운 빈 PowerShell 을 끈다.
# 대상: 부모가 데스크톱 앱(WindowsApps\Claude_*) NodeService 이고, 하위 프로세스가 없고, 1시간 넘은 powershell.exe
# -DryRun 이면 끄지 않고 대상만 출력한다.
param([switch]$DryRun, [int]$MinAgeMinutes = 60)

$all = Get-CimInstance Win32_Process
$hosts = $all | Where-Object {
  $_.Name -eq 'claude.exe' -and $_.CommandLine -match 'WindowsApps\\Claude_' -and $_.CommandLine -match 'utility-sub-type=node\.mojom\.NodeService'
} | ForEach-Object { [int]$_.ProcessId }
if (-not $hosts) { exit 0 }

$busy = @{}
$all | Where-Object { $_.Name -ne 'conhost.exe' } | ForEach-Object { $busy[[int]$_.ParentProcessId] = $true }
$cutoff = (Get-Date).AddMinutes(-$MinAgeMinutes)

$all | Where-Object {
  $_.Name -eq 'powershell.exe' -and ($hosts -contains [int]$_.ParentProcessId) -and
  -not $busy.ContainsKey([int]$_.ProcessId) -and $_.CreationDate -lt $cutoff
} | ForEach-Object {
  if ($DryRun) { "target $($_.ProcessId) $($_.CreationDate.ToString('MM-dd HH:mm'))" }
  else { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
exit 0
