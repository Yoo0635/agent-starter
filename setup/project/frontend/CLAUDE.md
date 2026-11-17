# WorkNX 프론트 — 작업 규칙

- 사용자는 프론트 · 디자인 담당. 서버는 별도 개발자 → 서버 코드를 만들지 말고, 필요한 API 는 `src/mocks/handlers/` 로 흉내 + `docs/API.md` 에 계약 추가.
- 기준 자료: 스토리보드 v5(2026-10-16) PDF가 정본. 화면 코드(F01-S1 등) ↔ 주소는 `src/app/screens.ts`, 진행 상황은 `docs/SCREENS.md`.
- 층 규칙(`docs/ARCHITECTURE.md`, eslint 가 검사): domain → lib → components → entities → features → app. 다른 기능 · 데이터 묶음은 `index.ts` 로만.
- 색 · 간격 · 크기는 `src/styles/tokens.css` 변수만. 상태 색은 `Tone` 으로.
- 새 화면은 공통 틀(`ListDetailFrame` · `DetailFrame` · `CenterFrame`) 안에서. 채운 버튼은 한 화면에 하나, 상태를 바꾸는 행동은 버튼, 꺼진 버튼엔 `disabledReason`.
- 상태 · 버튼 규칙은 `src/domain/*.ts` 한곳에서(화면과 가짜 서버가 같이 씀). 바꾸면 테스트도.
- 화면 문구는 v5 용어 그대로(담당 넘기기 · 확인 요청 · 접수/끝남 · 멈추기 · 퇴근 정리). 해요체.
- **반응형 필수**: 모든 화면은 360 · 390 · 768 · 820 · 1024 · 1280 · 1440 폭에서 가로 스크롤 없이. 구간별 값은 `styles/tokens.css`(≤1279 · ≤1100 · ≤900 · ≤768).
- **웹 접근성(KWCAG 2.2) 필수**: `docs/ACCESSIBILITY.md` 의 '새 화면 점검'. 새 화면은 `e2e/pages.ts` 에 추가, 상세 제목은 `DetailTitle`, 위치 · 색만의 안내 금지.
- 확인: `npm run typecheck && npm run lint && npm test && npm run e2e && npm run build`. 화면은 `npm run dev` 후 `/_ui` 와 실제 화면.
