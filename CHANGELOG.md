# 📋 Local-LLM-Arch 변경 이력 (Changelog)

이 문서는 `Local-LLM-Arch` 프로젝트의 모든 주요 업데이트, 최적화, 기능 추가 및 버그 수정 내역을 시간순으로 기록하는 공식 변경 이력입니다.

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
