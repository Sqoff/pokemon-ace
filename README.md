# Pokémon ACE (Action Combat Edition)

[![Engine](https://img.shields.io/badge/Godot-4.x-blue?logo=godotengine)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Style](https://img.shields.io/badge/Gen_2-Gold%2FSilver-gold)](https://github.com/Sqoff/pokemon-ace)

**Pokémon ACE**는 포켓몬스터 2세대(골드/실버)의 감성을 담은 클래식 오버월드 시스템 위에, 기존의 턴제 배틀 대신 **탑뷰 1:1 실시간 액션 전투 아레나**를 결합한 **Godot 4** 기반 오픈소스 팬게임 프로젝트입니다.

---

## 🎮 핵심 특징 (Core Features)

### 1. 2세대 포켓몬 골드 오버월드 시스템
* **16×16 그리드 스텝 이동:** `RayCast2D` 기반 장애물 판정 및 언덕(Ledge) 1방향 점프 구현.
* **실시간 낮/밤 사이클 (Day & Night):** `CanvasModulate`를 활용한 새벽(Morning), 낮(Day), 밤(Night) 3단계 색조 보간 및 시간대별 인카운터 테이블 연동.
* **2세대 4포켓 가방:** 일반 도구, 몬스터볼, 기술머신(TM/HM), 중요한 물건 4개 주머니 분리 관리.
* **필드 인터랙션:** NPC 대화 시스템, 표지판, 문(Door/Warp) 페이드 인/아웃 씬 전환.

### 2. 실시간 1:1 탑뷰 액션 배틀 아레나
* **전용 아레나 씬:** 풀숲/트레이너 조우 시 화면 전환 연출과 함께 닫힌 사각 링 형태의 경기장(`BattleArena.tscn`)으로 전환.
* **직접 조작 & 무빙:** 키보드 8방향 자유 이동을 통해 적의 공격과 투사체를 실시간으로 회피.
* **4개 기술 시스템 (PP 기반):** 
  * 4개 단축키(`Z/X/C/V` 또는 `1/2/3/4`)로 기술 발동.
  * 기술 시전 시 원작의 **PP(Power Points)** 소모 및 쿨다운 관리.
* **실시간 몬스터볼 투척 & 포획:**
  * 배틀 중 실시간으로 조준선을 띄워 몬스터볼 투사체를 던져 포획 시도.
  * 적의 남은 체력에 비례한 실시간 포획 확률 연산.
* **적 FSM AI:** 추적(Chase), 스킬 시전(Attack), 방황(Wander) 상태머신 기반 야생 포켓몬 AI.

---

## 📂 프로젝트 구조

```text
pokemon-ace/
├── docs/
│   └── spec_pokemon_action_arena.md   # 세부 설계, 개발 로드맵, 검증 체크리스트
├── resources/                         # Pokemon, Move, Item 데이터 리소스
├── scenes/
│   ├── overworld/                     # 타일맵, 플레이어, 건물, 이벤트 씬
│   ├── battle/                        # 배틀 아레나, 포켓몬 액터, 투사체 씬
│   └── ui/                            # HUD, 대화창, 가방, 포켓몬 메뉴
├── scripts/                           # 매니저 및 시스템 싱글톤 (TimeManager, SaveManager 등)
├── SPECIFICATION.md                   # 전체 시스템 개발 명세서 (SSOT)
└── project.godot                      # Godot 4 프로젝트 설정 파일
```

---

## 📋 개발 명세 및 가이드

상세한 시스템 아키텍처 다이어그램, Phase 1~5 개발 로드맵, 단계별 검증 체크리스트는 [SPECIFICATION.md](SPECIFICATION.md) 또는 [docs/spec_pokemon_action_arena.md](docs/spec_pokemon_action_arena.md)를 참고하세요.

---

## ⚖️ 라이선스 및 면책 조항 (Disclaimer)

* 본 프로젝트의 소스 코드는 **[MIT License](LICENSE)**에 따라 오픈소스로 배포됩니다.
* 일부 오버월드 그리드 이동 코드는 [pokemon-fireleaf-godot](https://github.com/SlayHorizon/pokemon-fireleaf-godot) (by SlayHorizon, MIT License)를 참조/기반으로 합니다.
* **포켓몬(Pokémon) 관련 지적재산권(상표, 캐릭터 디자인, 사운드 등)에 대한 모든 권리는 Nintendo, Game Freak, Creatures Inc.에 있습니다.** 본 프로젝트는 수익을 창출하지 않는 순수 기술 연구 및 학습 목적의 비영리 팬메이드 프로젝트입니다.
