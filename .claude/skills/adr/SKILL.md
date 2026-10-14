---
name: adr
description: 기술 선택, 구조, 데이터 형식처럼 되돌리기 어려운 결정을 내렸거나 내려야 할 때 사용. docs/adr/ADR-NNN-<결정>.md를 템플릿대로 만들고 architecture.md에 링크한다.
---

# ADR 작성

1. `docs/adr/`에서 가장 큰 `NNN`에 1을 더한다. 폴더가 없으면 `001`이다. 지운 번호는 다시 쓰지 않는다.
2. 파일 이름은 영어 kebab-case로 짓는다 (예: `ADR-002-use-postgres.md`). 이름을 보여주고 확인받는다.
3. `templates/adr/adr-TEMPLATE.md`를 복사해 채운다. 섹션 제목과 순서는 바꾸지 않는다.
4. 상태는 사용자가 결정을 확정하기 전이면 `제안`, 확정했으면 `승인`으로 쓴다.
5. 사용자가 말하지 않은 맥락이나 결과는 지어내지 않고 `[확인 필요]`로 둔다.
6. 기존 ADR을 바꾸는 결정이면, 기존 ADR의 상태를 `대체됨`으로 고치고 새 ADR 링크를 단다.
7. `docs/design/architecture.md`의 '주요 결정'에 링크를 추가한다. 파일이 없으면 `templates/design/architecture-TEMPLATE.md`로 만든다.

## 쓰지 않는 경우

- 쉽게 되돌릴 수 있는 결정 (이름 짓기, 설정값 조정 등)
