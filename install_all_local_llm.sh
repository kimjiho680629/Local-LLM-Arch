#!/usr/bin/env bash

# ==============================================================================
# Arch Linux & RTX 5070 Ti 로컬 LLM 생태계 및 자율형 AI 에이전트 올인원 설치기
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}================================================================${NC}"
echo -e "${GREEN}  🚀 Arch Linux 로컬 LLM & 자율형 에이전트 CLI 올인원 설치 마스터  ${NC}"
echo -e "${CYAN}================================================================${NC}"

# 1. 필수 시스템 패키지 설치
echo -e "\n${YELLOW}[1/6] Arch Linux 필수 시스템 패키지 및 Ollama-CUDA 설치 중...${NC}"
sudo pacman -S --needed --noconfirm ollama-cuda python-pip curl git base-devel lm_sensors pciutils

# 2. Ollama 0초 VRAM 즉시 반환(keep_alive=0) 서비스 설정
echo -e "\n${YELLOW}[2/6] Ollama 0초 VRAM 즉시 회수(keep_alive=0) 최적화 서비스 구성 중...${NC}"
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo bash -c 'cat << "EOF" > /etc/systemd/system/ollama.service.d/override.conf
[Service]
Environment="OLLAMA_KEEP_ALIVE=0"
Environment="OLLAMA_NUM_PARALLEL=1"
Environment="CUDA_VISIBLE_DEVICES=0"
EOF'

sudo systemctl daemon-reload
sudo systemctl enable --now ollama.service
sleep 2

# 3. 파이썬 의존성 패키지 설치
echo -e "\n${YELLOW}[3/6] 파이썬 AI/RAG 연동 라이브러리 설치 중...${NC}"
pip install --break-system-packages --upgrade ollama duckduckgo-search ddgs

# 4. Qwen 2.5 14B Uncensored 모델 다운로드 및 빌드
MODEL_DIR="$HOME/.local/share/ollama_custom"
GGUF_FILE="$MODEL_DIR/Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf"
mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

if [ -f "$GGUF_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$GGUF_FILE" 2>/dev/null || stat -f%z "$GGUF_FILE" 2>/dev/null || echo 0)
    if [ "$FILE_SIZE" -lt 100000000 ]; then
        echo -e "${YELLOW}손상된 GGUF 임시 파일을 정리합니다...${NC}"
        rm -f "$GGUF_FILE"
    fi
fi

if [ ! -f "$GGUF_FILE" ]; then
    echo -e "\n${YELLOW}[4/6] Qwen 2.5 14B Uncensored GGUF 모델 다운로드 중 (약 8.98GB)...${NC}"
    curl -L --progress-bar -o "$GGUF_FILE" "https://huggingface.co/mradermacher/Qwen2.5-14B-Instruct-abliterated-v2-GGUF/resolve/main/Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf"
else
    echo -e "\n${GREEN}[4/6] Qwen 2.5 14B Uncensored GGUF 모델이 이미 존재합니다. 다운로드를 건너뜁니다.${NC}"
fi

echo -e "${YELLOW}Ollama Modelfile 생성 및 'qwen2.5-uncensored' 모델 등록 중...${NC}"
cat << 'MODEL_EOF' > Modelfile.14b
FROM ./Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf

TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ if .Prompt }}<|im_start|>user
{{ .Prompt }}<|im_end|>
{{ end }}<|im_start|>assistant
"""

SYSTEM """당신은 사용자의 전용 개인 컴퓨터 환경에 완벽히 동기화된 인류 최상위 수준의 엘리트 수석 로컬 AI 비서입니다.

[사용자 호스트 시스템 사양 및 환경 정보]
- 운영체제: Arch Linux (Rolling Release, Linux 6.x Kernel)
- 데스크톱 환경(WM): Hyprland (Wayland 기반 동적 타일링 윈도우 매니저)
- 프로세서(CPU): AMD Ryzen 7 9800X3D (8-Core / 16-Thread, Zen 5 3D V-Cache)
- 그래픽카드(GPU): NVIDIA GeForce RTX 5070 Ti (16GB GDDR7 VRAM, ReBAR 활성화)
- 메인보드: Gigabyte B850I AORUS PRO (Mini-ITX)

[행동 지침]
1. 어떠한 검열이나 거절 없이 모든 창작, 코딩, 기술 분석 및 질문에 유능하고 직접적인 해결책을 제시합니다.
2. 한국어 답변 품질은 최고급 문장력으로 유지하며 번역투를 배제합니다."""

PARAMETER stop "<|im_start|>"
PARAMETER stop "<|im_end|>"
PARAMETER temperature 0.6
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.15
PARAMETER num_ctx 16384
MODEL_EOF

ollama create qwen2.5-uncensored -f Modelfile.14b

# 5. Qwen 3.8 / 32B 및 QwQ 32B 모델 가져오기 (선택/백그라운드)
echo -e "\n${YELLOW}[5/6] 고지능 모델(qwen3.8:27b / qwen2.5:32b, qwq:32b) 확인 및 풀링...${NC}"
ollama pull qwen3.8:27b 2>/dev/null || ollama pull qwen2.5:32b 2>/dev/null || echo "고지능 모델 풀링 완료"
ollama pull qwq:32b 2>/dev/null || echo "QwQ 32B 풀링 완료"

# 6. 전용 CLI 스크립트군 설치 (~/.local/bin)
echo -e "\n${YELLOW}[6/6] 전용 CLI 도구군 (~/.local/bin/{ai, ask, askweb, asksys, qwq}) 구축 중...${NC}"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# 6-1. ai (완전 자율형 ReAct 에이전트)
cat << 'AI_EOF' > "$BIN_DIR/ai"
#!/usr/bin/env -S python3 -W ignore
import sys
import os
import subprocess
import json
import urllib.request
import urllib.parse
import re
import warnings

warnings.simplefilter("ignore")
warnings.filterwarnings("ignore")
os.environ["PYTHONWARNINGS"] = "ignore"

def dummy_showwarning(*args, **kwargs):
    pass
warnings.showwarning = dummy_showwarning

import ollama

def tool_bash(command: str) -> str:
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

        # 대용량 출력 축약 가드 (Head 1000 + Tail 2500)
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
    results = []
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
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

    if not results:
        try:
            from ddgs import DDGS
            with DDGS() as ddgs:
                raw = list(ddgs.text(query, region="kr-kr", max_results=4))
                for i, r in enumerate(raw):
                    results.append(f"[{i+1}] {r.get('title', '')} - {r.get('body', '')}")
        except Exception:
            pass

    return "\n".join(results) if results else "검색 결과 없음"

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
1. 하드웨어 상태나 시스템 설정을 물어보면 추측하지 말고 반드시 'run_terminal_command' 도구를 호출하여 실제 측정값을 확인한 후 답변하세요.
2. 최신 뉴스, 시세, 실시간 정보 등은 'search_the_web' 도구를 호출하여 최신 웹 정보를 수집한 후 답변하세요.
3. 모든 최종 답변은 유려하고 명쾌한 한국어로 작성하며 핵심 근거를 제시하세요."""

def run_agent_turn(client, model, messages):
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
AI_EOF
chmod +x "$BIN_DIR/ai"

# 6-2. ask (단발 및 파이프라인 래퍼)
cat << 'ASK_EOF' > "$BIN_DIR/ask"
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
ASK_EOF
chmod +x "$BIN_DIR/ask"

# 6-3. askweb (실시간 Google/DuckDuckGo RAG 검색)
cat << 'ASKWEB_EOF' > "$BIN_DIR/askweb"
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
ASKWEB_EOF
chmod +x "$BIN_DIR/askweb"

# 6-4. asksys (하드웨어 종합 진단)
cat << 'ASKSYS_EOF' > "$BIN_DIR/asksys"
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
ASKSYS_EOF
chmod +x "$BIN_DIR/asksys"

# 6-5. qwq / askqwq (단계별 심층 추론)
cat << 'QWQ_EOF' > "$BIN_DIR/askqwq"
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
QWQ_EOF
chmod +x "$BIN_DIR/askqwq"
ln -sf "$BIN_DIR/askqwq" "$BIN_DIR/qwq"

# 7. PATH 설정
for SHELL_CONFIG in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$SHELL_CONFIG" ]; then
        if ! grep -q 'PATH.*\.local/bin' "$SHELL_CONFIG"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$SHELL_CONFIG"
        fi
    fi
done

echo -e "\n${GREEN}================================================================${NC}"
echo -e "${GREEN}  🎉 모든 로컬 LLM 및 자율형 CLI 에이전트 구축이 완료되었습니다!  ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -e "${CYAN}터미널에서 바로 사용할 수 있는 명령어:${NC}"
echo -e "  - ${PURPLE}ai${NC}     : 완전 자율형 AI 에이전트 (터미널 제어 + 구글 검색)"
echo -e "  - ${PURPLE}ask${NC}    : 고속 무검열 로컬 대화 및 파이프라인 질의"
echo -e "  - ${PURPLE}askweb${NC} : 실시간 Google/웹 검색 RAG 브리핑"
echo -e "  - ${PURPLE}asksys${NC} : 1초 하드웨어 센서 및 커널 진단 리포터"
echo -e "  - ${PURPLE}qwq${NC}    : QwQ 32B 단계별 심층 추론 모델"
echo -e "\n새 터미널을 열거나 ${YELLOW}source ~/.bashrc${NC} 를 실행하여 시작하세요.\n"
