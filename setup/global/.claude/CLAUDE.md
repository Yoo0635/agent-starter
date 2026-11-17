@AGENTS.md

## 답변 형식: 3줄 요약
- 모든 세션의 모든 답변은 간단히 3줄 이내로 요약해서 말한다.

## 사내 SSH (2026-09-04 전환)
- 사내 기기 SSH 포트는 전부 **22022** (22 는 닫힘): air=<air IP>, pro=<pro IP>, mini=<mini IP>, win/db=<win IP>(user scalp), win209=<win209 IP>(user administrator).
- 접속·복사는 `~/.ssh/config` 별칭으로: `ssh air|pro|mini|win|win209`, `scp 파일 air:~/`. 스크립트·도구에 포트 22 하드코딩 금지.
- 209(Windows) 는 cmd AutoRun 배너 때문에 scp 가 깨진다. PowerShell EncodedCommand 또는 base64 우회로 전송.
