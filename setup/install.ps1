# setup/ 의 설정을 새 프로젝트와 홈(~/.claude, ~/.codex)에 복사한다.
#   프로젝트만:  .\install.ps1 -Project C:\path\to\new-project
#   전역만:      .\install.ps1 -Global
#   둘 다:       .\install.ps1 -Project C:\path\to\new-project -Global
# 프로젝트에 같은 파일이 있으면 건너뛴다(-Force 면 덮어씀). 전역 파일은 덮어쓰기 전에 <파일>.bak 로 남긴다.
param([string]$Project, [switch]$Global, [switch]$Force)

$root = $PSScriptRoot

function Copy-Tree($from, $to, [bool]$backup) {
  Get-ChildItem -Path $from -Recurse -File -Force | ForEach-Object {
    $dest = Join-Path $to $_.FullName.Substring($from.Length).TrimStart('\')
    New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
    if (Test-Path $dest) {
      if ($backup) { Copy-Item $dest "$dest.bak" -Force }
      elseif (-not $Force) { Write-Host "건너뜀(이미 있음): $dest"; return }
    }
    Copy-Item $_.FullName $dest -Force
    Write-Host "복사: $dest"
  }
}

if (-not $Project -and -not $Global) { Write-Host '사용법: .\install.ps1 [-Project <경로>] [-Global] [-Force]'; exit 1 }
if ($Project) { Copy-Tree (Join-Path $root 'project') (Resolve-Path $Project).Path $false }
if ($Global) { Copy-Tree (Join-Path $root 'global') $HOME $true }
