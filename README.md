# 🚀 Universal Local LLM & Autonomous Agent Master Guide
### 하드웨어 자동 감지(NVIDIA/AMD/Intel/CPU) 기반 로컬 LLM 및 자율형 AI 에이전트 구축 가이드

본 문서는 리눅스(Arch Linux, Ubuntu, Debian, Fedora 등) 환경에서 시스템 하드웨어(GPU 제조사, VRAM 크기, CPU, RAM)를 스스로 감지하여 **최적의 무검열 로컬 LLM 모델**과 **완전 자율형 AI 에이전트 CLI 도구군**을 100% 자동 구축하고 설정할 수 있도록 설계된 표준 마스터 가이드입니다.

---

## 📌 목차
1. [범용 아키텍처 및 하드웨어 티어(Tier) 체계](#1-범용-아키텍처-및-하드웨어-티어tier-체계)
2. [Ollama 엔진 설치 및 0초 VRAM 반환 최적화](#2-ollama-엔진-설치-및-0초-vram-반환-최적화)
3. [하드웨어 사양별 추천 모델 라인업](#3-하드웨어-사양별-추천-모델-라인업)
4. [동적 하드웨어 인식 전용 CLI 도구군 (`ai`, `ask`, `askweb`, `asksys`, `qwq`)](#4-동적-하드웨어-인식-전용-cli-도구군-ai-ask-askweb-asksys-qwq)
5. [안정성 & 컨텍스트 보호 핵심 설정 (트러블슈팅 완벽 방어)](#5-안정성--컨텍스트-보호-핵심-설정-트러블슈팅-완벽-방어)
6. [원클릭 범용 자동 설치 스크립트 (`install_all_local_llm.sh`)](#6-원클릭-범용-자동-설치-스크립트-install_all_local_llmsh)
7. [명령어 빠른 참조 (Quick Reference)](#7-명령어-빠른-참조-quick-reference)

---

## 1. 범용 아키텍처 및 하드웨어 티어(Tier) 체계

설치 스크립트와 실행 도구들은 PC의 하드웨어 스펙을 실시간 감지하여 아래의 3개 티어로 자동 분류하여 최적 설정을 적용합니다:

| 하드웨어 티어 | VRAM 사양 기준 | 적용 모델 구성 | 컨텍스트 (`num_ctx`) | 대표 지원 GPU 예시 |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1 (High-End)** | **14GB 이상** | • 메인: `Qwen 2.5 14B (Uncensored)`<br>• 에이전트: `Qwen 3.8 27B` / `32B`<br>• 추론: `QwQ 32B` | **16384 (16K)** | RTX 4090, 5090, 5070 Ti, 4080, RX 7900 XTX (16GB~32GB) |
| **Tier 2 (Mid-Range)** | **7GB ~ 13GB** | • 메인: `Qwen 2.5 7B / 8B`<br>• 에이전트: `Qwen 2.5 14B`<br>• 추론: `DeepSeek-R1 8B` | **8192 (8K)** | RTX 4060 Ti, 3060, 4070, RX 7600 XT, 6700 XT (8GB~12GB) |
| **Tier 3 (Entry / CPU)** | **7GB 미만 / CPU** | • 메인: `Qwen 2.5 3B`<br>• 에이전트: `Qwen 2.5 7B`<br>• 추론: `DeepSeek-R1 7B` | **4096 (4K)** | GTX 1660, RTX 3050, 내장 그래픽, 순수 CPU 전용 PC |

```
                              [사용자 터미널 질의]
                                       │
      ┌───────────────┬────────────────┼───────────────┬───────────────┐
      │               │                │               │               │
    [ ai ]         [ ask ]         [ askweb ]      [ asksys ]        [ qwq ]
(동적 자율 에이전트) (단발/파이프)   (Google 실시간) (하드웨어 진단) (단계별 추론)
      │               │                │               │               │
      │ 런타임 하드웨어│                │ DuckDuckGo    │ 센서/로그     │ <think>
      │ 실시간 자동감지│                │ Fallback      │ 1초 스캔      │ 심층 논리
      └───────┬───────┴────────────────┴───────┬───────┴───────────────┘
              │                                │
              ▼                                ▼
  ┌────────────────────────────────────────────────────────┐
  │         Ollama 백엔드 엔진 (GPU 자동 감지 및 가속)       │
  │  - Environment="OLLAMA_KEEP_ALIVE=0" (0초 VRAM 즉시 반환) │
  │  - num_ctx: VRAM 용량에 따라 4K ~ 16K 자동 스케일링     │
  └───────────────────────────┬────────────────────────────┘
                              │
      ┌───────────────────────┼───────────────────────┐
      ▼                       ▼                       ▼
 [ Tier 1: 14B~32B ]    [ Tier 2: 7B~14B ]     [ Tier 3: 3B~7B ]
 (초고사양 16GB+ VRAM)    (보급형 8GB~12GB VRAM)   (경량/CPU 전용 환경)
```

---

## 2. Ollama 엔진 설치 및 0초 VRAM 반환 최적화

### 1) GPU 벤더별 패키지 설치
* **Arch Linux 계열 (Arch, CachyOS, EndeavourOS, Manjaro)**:
  ```bash
  # NVIDIA GPU
  sudo pacman -S --needed ollama-cuda python-pip curl git base-devel lm_sensors pciutils

  # AMD Radeon GPU
  sudo pacman -S --needed ollama-rocm python-pip curl git base-devel lm_sensors pciutils

  # Intel GPU 또는 CPU 전용
  sudo pacman -S --needed ollama python-pip curl git base-devel lm_sensors pciutils
  ```

* **타 리눅스 배포판 (Ubuntu, Debian, Fedora 등)**:
  ```bash
  curl -fsSL https://ollama.com/install.sh | sh
  ```

### 2) 0초 VRAM 즉시 회수 (`keep_alive=0`) systemd 설정
대화가 종료되면 VRAM을 즉시 100% OS로 반환하여 고사양 3D 게임이나 그래픽 툴과 충돌 없이 멀티태스킹할 수 있도록 설정합니다.

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo bash -c 'cat << "EOF" > /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_KEEP_ALIVE=0"
Environment="OLLAMA_NUM_PARALLEL=1"
EOF'

sudo systemctl daemon-reload
sudo systemctl enable --now ollama.service
```

---

## 3. 하드웨어 사양별 추천 모델 라인업

### 1) Tier 1 (16GB+ VRAM): Qwen 2.5 14B Uncensored + Qwen 3.8 27B / 32B
```bash
MODEL_DIR="$HOME/.local/share/ollama_custom"
mkdir -p "$MODEL_DIR" && cd "$MODEL_DIR"

curl -L --progress-bar -o "Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf" \
    "https://huggingface.co/mradermacher/Qwen2.5-14B-Instruct-abliterated-v2-GGUF/resolve/main/Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf"

cat << 'EOF' > Modelfile.custom
FROM ./Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf
TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
{{ end }}<|im_start|>assistant
"""
PARAMETER stop "<|im_start|>"
PARAMETER stop "<|im_end|>"
PARAMETER temperature 0.6
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.15
PARAMETER num_ctx 16384
EOF

ollama create qwen2.5-uncensored -f Modelfile.custom
ollama pull qwen3.8:27b 2>/dev/null || ollama pull qwen2.5:32b
ollama pull qwq:32b
```

### 2) Tier 2 (8GB~12GB VRAM): Qwen 2.5 7B / 14B + DeepSeek-R1 8B
```bash
ollama pull qwen2.5:7b
ollama pull qwen2.5:14b
ollama pull deepseek-r1:8b
ollama cp qwen2.5:7b qwen2.5-uncensored
```

### 3) Tier 3 (8GB 미만 / CPU): Qwen 2.5 3B / 7B + DeepSeek-R1 7B
```bash
ollama pull qwen2.5:3b
ollama pull qwen2.5:7b
ollama pull deepseek-r1:7b
ollama cp qwen2.5:3b qwen2.5-uncensored
```

---

## 4. 동적 하드웨어 인식 전용 CLI 도구군 (`ai`, `ask`, `askweb`, `asksys`, `qwq`)

### 1) `ai` — 완전 자율형 로컬 AI ReAct 에이전트
실행되는 PC의 CPU, GPU, OS를 **런타임에 0.01초 만에 실시간 감지**하여 프롬프트에 주입하고, VRAM 용량에 따라 컨텍스트 윈도우(`num_ctx`)를 자동 스케일링합니다.

* 실행 파일: `~/.local/bin/ai`
* **내장된 안전 가드**:
  * 대용량 터미널 출력(3,500자 초과 시) Head 1,000자 + Tail 2,500자 분할 샘플링 (컨텍스트 오버플로우 원천 차단)
  * 위험 셸 명령어(`rm -rf /`, `mkfs` 등) 사전 필터링
  * Google + DuckDuckGo 하이브리드 자동 Fallback 웹 검색

### 2) `ask` — 초고속 파이프라인 & 단발 질의 도구
* 실행 파일: `~/.local/bin/ask`
* 설치된 모델 중 최적 모델을 자동 탐색하여 실행하며, 표준 입력 파이프(`cat file | ask`)를 완벽 지원.

### 3) `askweb` — 실시간 Google RAG 검색 CLI
* 실행 파일: `~/.local/bin/askweb`
* Google 한국어 실시간 인덱스를 검색하여 최신 뉴스, 날씨, 시세, 게임 패치노트를 요약 브리핑.

### 4) `asksys` — 1초 하드웨어 종합 진단 리포터
* 실행 파일: `~/.local/bin/asksys`
* GPU 상태, CPU 온도 센서, 메모리/디스크, 실패한 systemd 서비스, dmesg 커널 에러 로그를 1초 만에 긁어와 AI 종합 진단 리포트 출력.

### 5) `qwq` / `askqwq` — 단계별 심층 추론 CLI
* 실행 파일: `~/.local/bin/qwq`
* `<think>` 태그 기반의 단계별 사고 과정을 거쳐 고난도 코딩 및 논리적 디버깅 수행.

---

## 5. 안정성 & 컨텍스트 보호 핵심 설정 (트러블슈팅 완벽 방어)

1. **Jinja Chat Template 500 에러 (`no user query found in messages`) 방어**
   * 대용량 셸 출력 축약 가드(Truncation Guard) 및 동적 `num_ctx` 자동 조절을 통해 `user` 메시지 유실을 구조적으로 방지.
2. **0초 VRAM 회수로 고사양 게임 렉 방어**
   * `OLLAMA_KEEP_ALIVE=0` 설정으로 대화 완료 즉시 VRAM 100% 반환.
3. **셸 환경 변수 영구 등록**
   * `~/.bashrc` 및 `~/.zshrc`에 `export PATH="$HOME/.local/bin:$PATH"` 추가.

---

## 6. 원클릭 범용 자동 설치 스크립트 (`install_all_local_llm.sh`)

어떤 리눅스, 어떤 그래픽카드 사양에서도 아래 명령어 한 줄이면 시스템을 자동 진단하여 맞춤형으로 100% 자동 설치됩니다:

```bash
bash /home/kjh/Projects/Local-LLM-Arch/install_all_local_llm.sh
```

---

## 7. 명령어 빠른 참조 (Quick Reference)

| 명령어 | 주요 용도 | 실행 예시 |
| :--- | :--- | :--- |
| **`ai`** | **완전 자율형 에이전트 (PC 상태 점검 + 구글 검색 스스로 수행)** | `ai "내 그래픽카드 온도 확인하고 최신 뉴스 검색해줘"` |
| **`ask`** | 고속 단발 질의 및 파일 파이프라인 분석 | `cat config.conf \| ask "설정 오류 검토해줘"` |
| **`askweb`** | Google 한국어 실시간 RAG 검색 | `askweb "오늘 환율 및 주가 알려줘"` |
| **`asksys`** | 1초 만에 하드웨어 센서/로그 종합 진단 | `asksys "지금 렉 걸릴 요인이 있는지 점검해줘"` |
| **`qwq`** | 단계별 사고(`think`) 기반 수학/알고리즘 추론 | `qwq "이 알고리즘의 시간복잡도를 증명해줘"` |
