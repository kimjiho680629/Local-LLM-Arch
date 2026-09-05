# 📋 Local-LLM-Arch 변경 이력 (Changelog)

이 문서는 `Local-LLM-Arch` 프로젝트의 모든 주요 업데이트, 최적화, 기능 추가 및 버그 수정 내역을 시간순으로 기록하는 공식 변경 이력입니다.

---

## 📌 [2026-09-05] - v1.3.0: 2026년 기준 실시간 구글 검색 동기화 & 영구 세션 메모리 탑재
### 🌟 주요 추가 및 변경 사항
* **실시간 시간 동적 감지 & 2026년 기준 전역 주입**:
  * 모델 사전 학습 컷오프(2024~2025년)로 인해 "올해", "최신" 정보를 2025년으로 검색하던 현상을 원천 해결.
  * 시스템 `date` 기반 실시간 일시를 에이전트 시스템 프롬프트에 동적 주입.
  * Google 웹 검색 쿼리에서 과거 연도(2024, 2025) 감지 시 현재 연도(2026)로 스마트 자동 보정(`search_the_web`, `askweb`).
* **단발성 CLI 영구 세션 메모리(Persistent Session Memory) 구현 (`ai`)**:
  * 단발성 실행(`ai "질문"`) 시 프로세스가 종료되어도 최근 5개 턴(질문+답변)을 `~/.cache/ai_agent/session.json`에 영구 보관.
  * 후속 질문 시 "방금 말한 그거", "아까 알려준 내용" 등의 대명사와 문맥을 완벽히 유지하며 대화 가능.
  * 언제든 대화 기억을 즉시 비울 수 있는 초기화 명령어(`ai clear`, `ai reset`) 추가.
  * 1시간 이상 미사용 시 세션 자동 리셋 타임아웃 적용.
* **전역 모델 일원화 (`smart-qwen:latest`)**:
  * 2026년 기준 프롬프트와 최적화 하이퍼파라미터(temp 0.3, num_ctx 8192)가 내장된 `smart-qwen` 모델을 전역 CLI 도구(`ai`, `askweb`, `asksys`, `ask`)의 최우선 타깃 모델로 일원화.

---

## 📌 [2026-09-02 19:09:15] - GitHub 자동 업데이트 스크립트 안정화 및 CHANGELOG 동기화
* GitHub 자동 업데이트 스크립트 안정화 및 CHANGELOG 동기화

---

## 📌 [2026-09-02] - v1.2.0: Qwen 3.8 27B 주모델 확정 및 범용 하드웨어 자동 감지
### 🌟 주요 추가 및 변경 사항
* **Qwen 3.8 27B 주모델 확정**:
  * `ai` (자율 ReAct 에이전트), `ask`, `askweb` (Google RAG), `asksys` (하드웨어 진단)의 기본 엔진을 최고 지능 모델인 `qwen3.8:27b`로 일원화.
* **범용 하드웨어 실시간 자동 감지 엔진(Universal Auto-detection)**:
  * 런타임에 GPU 벤더(NVIDIA/AMD/Intel/CPU), VRAM 크기, CPU, OS를 스스로 감지하여 3단계 티어(Tier 1/2/3)별 최적 모델 및 컨텍스트(`num_ctx`)를 자동 스케일링.
* **동적 시스템 프롬프트(Dynamic System Prompt)**:
  * 에이전트 구동 시 호스트의 실제 하드웨어 명칭을 실시간으로 감지하여 프롬프트에 주입.
* **컨텍스트 오버플로우 방어(Truncation Guard)**:
  * 대용량 셸 출력 3,500자 초과 시 Head 1,000자 + Tail 2,500자 분할 샘플링을 적용하여 Jinja Template 500 에러 원천 차단.

---

## 📌 [2026-09-02] - v1.1.0: 완전 자율형 로컬 AI 에이전트 (`ai`) 및 컨텍스트 보호
### 🌟 주요 추가 및 변경 사항
* **완전 자율형 로컬 AI ReAct 에이전트 (`ai`) 구축**:
  * 리눅스 터미널 명령어 자율 실행(`run_terminal_command`) 및 Google 실시간 검색(`search_the_web`) 도구 호출 루프 탑재.
* **16K 컨텍스트 윈도우(`num_ctx: 16384`) 확장 및 0초 VRAM 즉시 반환(`keep_alive=0`) 적용**.

---

## 📌 [2026-09-02] - v1.0.0: 최초 릴리즈 (Initial Release)
### 🌟 주요 추가 및 변경 사항
* Arch Linux & RTX 5070 Ti 기반 무검열 로컬 LLM 마스터 가이드([`LOCAL_LLM_MASTER_GUIDE.md`](LOCAL_LLM_MASTER_GUIDE.md)) 및 올인원 원클릭 설치기([`install_all_local_llm.sh`](install_all_local_llm.sh)) 최초 배포.
