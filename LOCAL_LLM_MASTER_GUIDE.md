# 🚀 Arch Linux & RTX 5070 Ti 기반 로컬 LLM 완전 설치 및 설정 마스터 가이드

본 문서는 Arch Linux 및 NVIDIA RTX 5070 Ti (16GB VRAM) / Ryzen 7 9800X3D 환경에서 **100% 무검열(Uncensored) 고지능 로컬 LLM 생태계**와 **완전 자율형 AI 에이전트(CLI 도구군)**를 새 시스템에 처음부터 완벽하게 구축하고 설정할 수 있도록 정리한 표준 마스터 가이드입니다.

---

## 📌 목차
1. [시스템 요구사항 및 아키텍처 개요](#1-시스템-요구사항-및-아키텍처-개요)
2. [Ollama-CUDA 엔진 설치 및 서비스 최적화 (0초 VRAM 회수)](#2-ollama-cuda-엔진-설치-및-서비스-최적화-0초-vram-회수)
3. [로컬 모델 라인업 다운로드 및 Modelfile 빌드](#3-로컬-모델-라인업-다운로드-및-modelfile-빌드)
4. [전용 CLI 도구군 구축 (`ai`, `ask`, `askweb`, `asksys`, `qwq`)](#4-전용-cli-도구군-구축-ai-ask-askweb-asksys-qwq)
5. [안정성 & 컨텍스트 보호 핵심 설정 (트러블슈팅 완벽 가이드)](#5-안정성--컨텍스트-보호-핵심-설정-트러블슈팅-완벽-가이드)
6. [올인원 원클릭 설치 스크립트 (`install_all_local_llm.sh`)](#6-올인원-원클릭-설치-스크립트-install_all_local_llmsh)
7. [명령어 빠른 참조 (Quick Reference)](#7-명령어-빠른-참조-quick-reference)

---

## 1. 시스템 요구사항 및 아키텍처 개요

### 1) 권장 하드웨어 & OS 스펙
* **OS**: Arch Linux (Rolling Release, Linux 6.x Kernel)
* **CPU**: AMD Ryzen 7 9800X3D (Zen 5 3D V-Cache) 이상
* **GPU**: NVIDIA GeForce RTX 5070 Ti (16GB GDDR7 VRAM, ReBAR ON) 이상
* **RAM**: 32GB DDR5 이상
* **스토리지**: 최소 60GB 이상의 고속 NVMe SSD 여유 공간

### 2) 로컬 AI 생태계 구조
```
                                  [사용자 터미널]
                                         │
        ┌───────────────┬────────────────┼───────────────┬───────────────┐
        │               │                │               │               │
      [ ai ]         [ ask ]         [ askweb ]      [ asksys ]        [ qwq ]
  (자율 에이전트)  (단발/파이프)   (Google 실시간) (하드웨어 진단) (단계별 추론)
        │               │                │               │               │
        │ ReAct 도구    │                │ DuckDuckGo    │ 센서/로그     │ <think>
        │ (터미널/웹)   │                │ Fallback      │ 1초 스캔      │ 심층 논리
        └───────┬───────┴────────────────┴───────┬───────┴───────────────┘
                │                                │
                ▼                                ▼
    ┌────────────────────────────────────────────────────────┐
    │          Ollama 백엔드 엔진 (CUDA GPU 풀 오프로드)       │
    │  - Environment="OLLAMA_KEEP_ALIVE=0" (0초 VRAM 즉시 회수) │
    │  - num_ctx: 16384 (16K 컨텍스트 윈도우 보장)           │
    └───────────────────────────┬────────────────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        ▼                       ▼                       ▼
 [ qwen3.8:27b ]    [ qwen2.5-uncensored ]         [ qwq:32b ]
 (27B/32B 최고지능)     (14B 무검열 고속모델)       (32B 수학/추론특화)
```

---

## 2. Ollama-CUDA 엔진 설치 및 서비스 최적화 (0초 VRAM 회수)

### 1) 필수 패키지 설치
```bash
sudo pacman -S --needed --noconfirm \
    ollama-cuda \
    python-pip \
    curl \
    git \
    base-devel \
    lm_sensors \
    pciutils
```

### 2) 0초 VRAM 즉시 회수 (`keep_alive=0`) systemd 설정
게임(디아블로 4 등) 구동 시 VRAM 경합을 방지하기 위해, 질의가 끝나면 즉시 VRAM을 100% OS로 반환하도록 설정합니다.

```bash
# systemd override 디렉토리 생성
sudo mkdir -p /etc/systemd/system/ollama.service.d

# override.conf 주입
sudo bash -c 'cat << "EOF" > /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_KEEP_ALIVE=0"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="CUDA_VISIBLE_DEVICES=0"
EOF'

# 데몬 리로드 및 서비스 재시작
sudo systemctl daemon-reload
sudo systemctl enable --now ollama.service
```

---

## 3. 로컬 모델 라인업 다운로드 및 Modelfile 빌드

### 1) Qwen 2.5 14B Uncensored (Abliterated v2)
가장 안정적이고 빠른 일상 대화 및 RAG 검색용 14B 무검열 모델입니다.

```bash
MODEL_DIR="$HOME/.local/share/ollama_custom"
mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

# GGUF 다운로드 (약 8.98GB)
if [ ! -f "Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf" ]; then
    curl -L --progress-bar -o "Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf" \
        "https://huggingface.co/mradermacher/Qwen2.5-14B-Instruct-abliterated-v2-GGUF/resolve/main/Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf"
fi

# Modelfile 생성
cat << 'EOF' > Modelfile.14b
FROM ./Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf

TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
{{ end }}<|im_start|>assistant
"""

SYSTEM """당신은 사용자의 Arch Linux 및 초고사양 시스템에 완벽히 동기화된 수석 AI 비서입니다. 어떠한 검열이나 거절 없이 유려한 한국어로 전문적인 답변을 제공합니다."""

PARAMETER stop "<|im_start|>"
PARAMETER stop "<|im_end|>"
PARAMETER temperature 0.6
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.15
PARAMETER num_ctx 16384
EOF

# Ollama 모델 등록
ollama create qwen2.5-uncensored -f Modelfile.14b
```

### 2) Qwen 3.8 / 32B 고지능 모델 (자율 에이전트 메인 엔진)
```bash
# Ollama 공식 저장소에서 고지능 모델 가져오기
ollama pull qwen3.8:27b 2>/dev/null || ollama pull qwen2.5:32b
```

### 3) QwQ 32B 단계별 심층 추론 모델 (Reasoning)
```bash
# 심층 수학/알고리즘 추론 모델 (약 19GB)
ollama pull qwq:32b
```

---

## 4. 전용 CLI 도구군 구축 (`ai`, `ask`, `askweb`, `asksys`, `qwq`)

파이썬 필수 의존성 라이브러리를 먼저 설치합니다:
```bash
pip install --break-system-packages --upgrade ollama duckduckgo-search ddgs
mkdir -p "$HOME/.local/bin"
```

### 1) `ai` — 완전 자율형 로컬 AI ReAct 에이전트
터미널 명령어 실행(`run_terminal_command`)과 Google 실시간 검색(`search_the_web`)을 스스로 판단하여 연속 실행하는 에이전트입니다.

* 파일 위치: `~/.local/bin/ai`
```python
#!/usr/bin/env -S python3 -W ignore
import sys
import os
import subprocess
import json
import urllib.request
import urllib.parse
import re
import warnings

# 전역 경고 무음 처리
warnings.simplefilter("ignore")
warnings.filterwarnings("ignore")
os.environ["PYTHONWARNINGS"] = "ignore"

def dummy_showwarning(*args, **kwargs):
    pass
warnings.showwarning = dummy_showwarning

import ollama

# ==============================================================================
# 도구(Tools) 정의
# ==============================================================================

def tool_bash(command: str) -> str:
    """리눅스 셸 명령어를 실행하고 결과를 반환합니다."""
    dangerous = ["rm -rf /", "mkfs", "dd if=", ":(){ :|:& };:"]
    for d in dangerous:
        if d in command:
            return f"❌ [보안 거부] 시스템 위험 명령어가 감지되어 실행이 차단되었습니다: {command}"
    
    try:
        res = subprocess.run(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=15
        )
        out = res.stdout.strip()
        err = res.stderr.strip()
        result = out if out else ""
        if err:
            result += f"\n[stderr]: {err}"

        if not result:
            return "(출력 없음, 정상 실행됨)"

        # 대용량 출력 축약 가드 (Head 1,000자 + Tail 2,500자 보존)
        max_len = 3500
        if len(result) > max_len:
            head_len = 1000
            tail_len = 2500
            result = f"{result[:head_len]}\n\n... [중략: 총 {len(result)}자 중 {len(result) - head_len - tail_len}자 생략됨] ...\n\n{result[-tail_len:]}"

        return result
    except subprocess.TimeoutExpired:
        return "❌ [오류] 명령어 실행 시간 초과 (15초)"
    except Exception as e:
        return f"❌ [실행 실패]: {e}"

def tool_web_search(query: str) -> str:
    """Google 및 DuckDuckGo 웹 검색"""
    results = []
    # 1. Google HTTP 파서
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept-Language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7"
        }
        url = f"https://www.google.com/search?q={urllib.parse.quote(query)}&hl=ko&gl=kr&num=4"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as resp:
            html = resp.read().decode("utf-8", errors="ignore")
            titles = re.findall(r'<h3[^>]*>(.*?)</h3>', html)
            snippets = re.findall(r'<div[^>]+class="[^"]*(?:VwiC3b|yXK7lf|MUxGbd)[^"]*"[^>]*>(.*?)</div>', html)
            for i in range(min(len(titles), 4)):
                clean_title = re.sub(r'<.*?>', '', titles[i]).strip()
                clean_body = re.sub(r'<.*?>', '', snippets[i]).strip() if i < len(snippets) else ""
                if clean_title:
                    results.append(f"[{i+1}] {clean_title} - {clean_body}")
    except Exception:
        pass

    # 2. DuckDuckGo Fallback
    if not results:
        try:
            try:
                from ddgs import DDGS
            except Exception:
                from duckduckgo_search import DDGS
            with DDGS() as ddgs:
                raw = list(ddgs.text(query, region="kr-kr", max_results=4))
                for i, r in enumerate(raw):
                    results.append(f"[{i+1}] {r.get('title', '')} - {r.get('body', '')}")
        except Exception:
            pass

    return "\n".join(results) if results else "검색 결과 없음"

# ==============================================================================
# Ollama Tool Definitions & ReAct Loop
# ==============================================================================

TOOLS = [
    {
        'type': 'function',
        'function': {
            'name': 'run_terminal_command',
            'description': '리눅스 터미널 셸 명령어(하드웨어 상태, 센서, 프로세스, 파일 확인, 설정 변경 등)를 직접 실행합니다.',
            'parameters': {
                'type': 'object',
                'properties': {
                    'command': {
                        'type': 'string',
                        'description': '실행할 리눅스 bash 명령어 (예: nvidia-smi, sensors, uname -a, cat /path/to/file)'
                    }
                },
                'required': ['command']
            }
        }
    },
    {
        'type': 'function',
        'function': {
            'name': 'search_the_web',
            'description': '실시간 인터넷 웹(Google)을 검색하여 최신 뉴스, 날씨, 주가, 게임 패치노트 등을 수집합니다.',
            'parameters': {
                'type': 'object',
                'properties': {
                    'query': {
                        'type': 'string',
                        'description': '검색할 키워드 또는 질의어'
                    }
                },
                'required': ['query']
            }
        }
    }
]

SYSTEM_PROMPT = """당신은 사용자의 Arch Linux 및 초고사양 하드웨어(Ryzen 9800X3D + RTX 5070 Ti) 시스템을 완전히 제어할 수 있는 자율형 AI 수석 엔지니어 에이전트(Autonomous Agent)입니다.

[자율 에이전트 행동 수칙]
1. 하드웨어 상태나 시스템 설정을 물어보면 추측하지 말고 반드시 'run_terminal_command' 도구를 실행하여 실제 측정값을 확인한 후 답변하세요.
2. 최신 뉴스, 시세, 실시간 정보 등은 'search_the_web' 도구를 호출하여 최신 웹 정보를 수집한 후 답변하세요.
3. 모든 최종 답변은 유려하고 명쾌한 한국어로 핵심 근거를 제시하세요."""

def run_agent_turn(client, model, messages):
    """자율형 ReAct 루프 실행"""
    max_loops = 6
    loop_count = 0

    while loop_count < max_loops:
        loop_count += 1
        
        try:
            response = client.chat(
                model=model,
                messages=messages,
                tools=TOOLS,
                options={
                    'temperature': 0.3,
                    'num_ctx': 16384
                },
                keep_alive=0
            )
        except Exception as e:
            return f"❌ [Ollama 응답 처리 오류]: {e}\n(도구 실행 결과량이 너무 많거나 모델 템플릿에서 오류가 발생했습니다.)"

        message = response['message']
        messages.append(message)

        if not message.get('tool_calls'):
            return message.get('content', '')

        for tool_call in message['tool_calls']:
            fn_name = tool_call['function']['name']
            fn_args = tool_call['function']['arguments']

            print(f"\033[0;35m⚡ [자율 에이전트 도구 실행]\033[0m: {fn_name}")
            
            tool_output = ""
            if fn_name == 'run_terminal_command':
                cmd = fn_args.get('command', '')
                print(f"  \033[0;34m$ {cmd}\033[0m")
                tool_output = tool_bash(cmd)
                print(f"  \033[0;32m↳ 결과 수집 완료 ({len(tool_output)}자)\033[0m")
            
            elif fn_name == 'search_the_web':
                query = fn_args.get('query', '')
                print(f"  \033[0;34m🔍 구글 검색: {query}\033[0m")
                tool_output = tool_web_search(query)
                print(f"  \033[0;32m↳ 웹 검색 완료\033[0m")

            messages.append({
                'role': 'tool',
                'content': str(tool_output)
            })

    return "❌ 도구 실행 루프 한도 초과"

def main():
    client = ollama.Client()
    target_model = 'qwen3.8:27b'
    try:
        client.show(target_model)
    except Exception:
        target_model = 'qwen2.5:32b'
        try:
            client.show(target_model)
        except Exception:
            target_model = 'qwen2.5-uncensored'

    # 단발성 인수 실행
    if len(sys.argv) > 1:
        user_prompt = " ".join(sys.argv[1:])
        messages = [
            {'role': 'system', 'content': SYSTEM_PROMPT},
            {'role': 'user', 'content': user_prompt}
        ]
        print(f"\033[0;36m🤖 [자율형 에이전트 가동 (모델: {target_model})]\033[0m")
        print(f"👤 사용자 요청: {user_prompt}\n")
        answer = run_agent_turn(client, target_model, messages)
        print(f"\n\033[0;32m🤖 [최종 답변]:\033[0m\n{answer}")
        return

    # 대화형 REPL 모드
    print(f"\033[0;36m====================================================\033[0m")
    print(f"\033[0;32m  🚀 완전 자율형 로컬 AI 에이전트 (ai) 시작  \033[0m")
    print(f"\033[0;36m  종료: /bye 또는 exit | 초기화: /clear\033[0m")
    print(f"\033[0;36m====================================================\033[0m\n")

    history = [{'role': 'system', 'content': SYSTEM_PROMPT}]

    while True:
        try:
            user_input = input("\033[1;34mAI >>> \033[0m").strip()
            if not user_input:
                continue
            if user_input in ['/bye', 'exit', 'quit']:
                print("\033[0;33m자율형 에이전트를 종료합니다.\033[0m")
                break
            if user_input in ['/clear', 'clear']:
                history = [{'role': 'system', 'content': SYSTEM_PROMPT}]
                print("\033[0;32m대화 기억이 초기화되었습니다.\033[0m")
                continue

            history.append({'role': 'user', 'content': user_input})
            answer = run_agent_turn(client, target_model, history)
            print(f"\n\033[0;32m🤖 [답변]:\033[0m\n{answer}\n")

        except (KeyboardInterrupt, EOFError):
            print("\n\033[0;33m자율형 에이전트를 종료합니다.\033[0m")
            break

if __name__ == '__main__':
    main()
```
```bash
chmod +x "$HOME/.local/bin/ai"
```

### 2) `ask` — 초고속 파이프라인 & 단발 질의 래퍼
* 파일 위치: `~/.local/bin/ask`
```bash
#!/usr/bin/env bash
if [ -p /dev/stdin ]; then
    STDIN_DATA=$(cat)
    if [ $# -gt 0 ]; then
        PROMPT="$*\n\n[입력 데이터]:\n$STDIN_DATA"
    else
        PROMPT="$STDIN_DATA"
    fi
    ollama run qwen2.5-uncensored "$PROMPT"
else
    if [ $# -gt 0 ]; then
        ollama run qwen2.5-uncensored "$*"
    else
        ollama run qwen2.5-uncensored
    fi
fi
```
```bash
chmod +x "$HOME/.local/bin/ask"
```

### 3) `askweb` — Google 한국어 RAG 실시간 웹 검색 CLI
* 파일 위치: `~/.local/bin/askweb`
```python
#!/usr/bin/env -S python3 -W ignore
import sys
import os
import warnings
warnings.simplefilter("ignore")
import urllib.request
import urllib.parse
import re
import ollama

def search_web(query, max_results=4):
    results = []
    try:
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
        url = f"https://www.google.com/search?q={urllib.parse.quote(query)}&hl=ko&gl=kr&num={max_results+2}"
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as response:
            html = response.read().decode("utf-8", errors="ignore")
            titles = re.findall(r'<h3[^>]*>(.*?)</h3>', html)
            snippets = re.findall(r'<div[^>]+class="[^"]*(?:VwiC3b|yXK7lf|MUxGbd)[^"]*"[^>]*>(.*?)</div>', html)
            for i in range(min(len(titles), max_results)):
                t = re.sub(r'<.*?>', '', titles[i]).strip()
                b = re.sub(r'<.*?>', '', snippets[i]).strip() if i < len(snippets) else ""
                if t:
                    results.append(f"[{i+1}] {t} - {b}")
    except Exception:
        pass

    if not results:
        try:
            from ddgs import DDGS
            with DDGS() as ddgs:
                for i, r in enumerate(ddgs.text(query, region="kr-kr", max_results=max_results)):
                    results.append(f"[{i+1}] {r.get('title', '')} - {r.get('body', '')}")
        except Exception:
            pass

    return "\n".join(results)

def main():
    if len(sys.argv) < 2:
        print("사용법: askweb \"검색할 질문 내용을 입력하세요\"")
        sys.exit(1)

    query = " ".join(sys.argv[1:])
    print(f"\033[0;34m🔍 [Google 실시간 검색 중...]\033[0m: {query}\n")
    search_data = search_web(query)

    prompt = f"""[실시간 웹 검색 결과]
{search_data if search_data else "검색 결과 없음"}

[질문]
{query}

위 검색 결과를 최우선으로 분석하여 한국어로 알기 쉽게 상세히 답변하세요."""

    res = ollama.chat(
        model='qwen2.5-uncensored',
        messages=[{'role': 'user', 'content': prompt}],
        options={'temperature': 0.4}
    )
    print(f"\033[0;32m🤖 [로컬 AI 답변]:\033[0m\n{res['message']['content']}")

if __name__ == '__main__':
    main()
```
```bash
chmod +x "$HOME/.local/bin/askweb"
```

### 4) `asksys` — 1초 시스템 하드웨어 종합 진단 리포터
* 파일 위치: `~/.local/bin/asksys`
```bash
#!/usr/bin/env bash
USER_QUERY="$*"
if [ -z "$USER_QUERY" ]; then
    USER_QUERY="현재 시스템 하드웨어 상태(온도, VRAM, RAM, CPU, 디스크, 실패한 서비스, 커널 에러)를 종합적으로 분석하고 문제 여부를 진단해줘."
fi

echo -e "\033[0;34m⚡ [시스템 하드웨어 및 커널 상태 초고속 수집 중...]\033[0m"

SYS_INFO="[1. GPU 상태 (nvidia-smi)]\n$(nvidia-smi 2>/dev/null || echo 'N/A')\n\n"
SYS_INFO+="[2. CPU/온도 센서 (sensors)]\n$(sensors 2>/dev/null | grep -E 'Tctl|Tdie|temp1|Package|Core' || sensors 2>/dev/null | head -20)\n\n"
SYS_INFO+="[3. 메모리 상태 (free -h)]\n$(free -h)\n\n"
SYS_INFO+="[4. 디스크 용량 (df -h)]\n$(df -h / /home 2>/dev/null)\n\n"
SYS_INFO+="[5. 실패한 systemd 서비스]\n$(systemctl --failed --no-pager 2>/dev/null | head -10)\n\n"
SYS_INFO+="[6. 최근 커널 에러 로그 (dmesg)]\n$(dmesg --level=err,warn 2>/dev/null | tail -15 || echo '권한 없음 또는 에러 없음')"

PROMPT="당신은 Arch Linux 및 초고사양 시스템 전문 수석 엔지니어입니다.
아래 실시간 시스템 하드웨어 덤프 데이터를 정밀 분석하여 사용자 질문에 대해 명쾌한 종합 진단 리포트를 작성하세요.

$SYS_INFO

[사용자 요청]
$USER_QUERY"

echo -e "\033[0;32m🤖 [수석 엔지니어 AI 진단 리포트 생성 중...]\033[0m\n"
ollama run qwen2.5-uncensored "$PROMPT"
```
```bash
chmod +x "$HOME/.local/bin/asksys"
```

### 5) `qwq` / `askqwq` — QwQ 32B 단계별 심층 추론 CLI
* 파일 위치: `~/.local/bin/askqwq`
```bash
#!/usr/bin/env bash
if [ -p /dev/stdin ]; then
    STDIN_DATA=$(cat)
    if [ $# -gt 0 ]; then
        PROMPT="$*\n\n[입력 데이터]:\n$STDIN_DATA"
    else
        PROMPT="$STDIN_DATA"
    fi
    ollama run qwq:32b "$PROMPT"
else
    if [ $# -gt 0 ]; then
        ollama run qwq:32b "$*"
    else
        ollama run qwq:32b
    fi
fi
```
```bash
chmod +x "$HOME/.local/bin/askqwq"
ln -sf "$HOME/.local/bin/askqwq" "$HOME/.local/bin/qwq"
```

---

## 5. 안정성 & 컨텍스트 보호 핵심 설정 (트러블슈팅 완벽 가이드)

### 1) 템플릿 에러 `no user query found in messages (status code: 500)` 방어
* **원인**: 에이전트가 `journalctl` 등 수만 자의 로그를 한 번에 가져오면 컨텍스트 윈도우가 가득 차면서 앞단의 `user` 메시지가 Truncation(잘림)되어 Qwen Jinja Template의 `raise_exception`을 유발함.
* **해결책**:
  1. `tool_bash` 내에 **최대 3,500자 Truncation Guard (Head 1,000자 + Tail 2,500자 보존)** 적용.
  2. Ollama 호출 옵션에 `num_ctx: 16384` (16K 컨텍스트) 명시.

### 2) VRAM 스와핑 및 게임 렉 방어
* `Environment="OLLAMA_KEEP_ALIVE=0"`을 systemd override에 등록하여 사용 후 VRAM을 즉시 해제함으로써 고사양 게임(디아블로4 등)과 완벽한 멀티태스킹 보장.

### 3) 셸 PATH 영구 등록
`~/.bashrc` 및 `~/.zshrc`에 다음 설정을 추가합니다:
```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## 6. 올인원 원클릭 설치 스크립트 (`install_all_local_llm.sh`)

새로운 Arch Linux 시스템 환경에서 본 스크립트 하나만 실행하면 위 1~5단계의 모든 패키지, 모델 다운로드, Modelfile 빌드, 서비스 등록, CLI 도구 생성이 100% 자동 완료됩니다.

* 스크립트 위치: [`/home/kjh/Projects/Gemini_Job/install_all_local_llm.sh`](file:///home/kjh/Projects/Gemini_Job/install_all_local_llm.sh)

---

## 7. 명령어 빠른 참조 (Quick Reference)

| 명령어 | 주요 용도 | 예시 |
| :--- | :--- | :--- |
| **`ai`** | **완전 자율형 에이전트 (PC 제어 + 구글 검색 스스로 수행)** | `ai "내 그래픽카드 온도 확인하고 최신 드라이버 뉴스 검색해줘"` |
| **`ask`** | 단발 질의 및 파이프라인 빠른 대화 | `cat main.py \| ask "코드 최적화해줘"` |
| **`askweb`** | Google 한국어 실시간 RAG 검색 | `askweb "오늘 원달러 환율 및 주가 알려줘"` |
| **`asksys`** | 1초 만에 하드웨어 센서/로그 종합 진단 | `asksys "지금 렉 걸릴 요인이 있는지 점검해줘"` |
| **`qwq`** | 단계별 사고(`think`) 기반 복잡한 수학/코딩 추론 | `qwq "복잡한 알고리즘 시간복잡도 증명해줘"` |
