#!/usr/bin/env bash

# ==============================================================================
# 🚀 Universal Local LLM & Autonomous Agent Installer (All Linux & All GPUs)
# 하드웨어(NVIDIA/AMD/Intel/CPU), VRAM 용량, OS 환경을 스스로 감지하여
# 최적의 모델과 컨텍스트를 100% 자동 세팅하는 범용 마스터 설치기
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
echo -e "${GREEN}  🌐 범용 하드웨어 자동 감지 로컬 LLM & 자율형 에이전트 올인원 설치  ${NC}"
echo -e "${CYAN}================================================================${NC}"

# ==============================================================================
# [단계 1] 호스트 하드웨어 & OS 정밀 자동 감지
# ==============================================================================
echo -e "\n${YELLOW}[1/6] 시스템 하드웨어 및 GPU/VRAM 환경 정밀 진단 중...${NC}"

# 1-1. CPU 및 RAM 감지
CPU_MODEL=$(lscpu 2>/dev/null | grep 'Model name:' | sed 's/Model name:[ \t]*//' || grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs || echo "Generic CPU")
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
echo -e "  • ${BLUE}CPU${NC}: $CPU_MODEL"
echo -e "  • ${BLUE}RAM${NC}: ${TOTAL_RAM_GB} GB"

# 1-2. GPU 종류 및 VRAM 크기 감지
GPU_TYPE="cpu"
GPU_NAME="Integrated / CPU"
VRAM_GB=0

if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    GPU_TYPE="nvidia"
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
    VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
    VRAM_GB=$(( (VRAM_MB + 512) / 1024 ))
elif lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -qi 'amd\|radeon\|advanced micro'; then
    GPU_TYPE="amd"
    GPU_NAME=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -i 'amd\|radeon' | head -n1 | cut -d: -f3 | xargs)
    # sysfs 또는 rocm-smi에서 VRAM 감지 시도
    if [ -d "/sys/class/drm/card0/device" ] && [ -f "/sys/class/drm/card0/device/mem_info_vram_total" ]; then
        VRAM_BYTES=$(cat /sys/class/drm/card0/device/mem_info_vram_total 2>/dev/null || echo 0)
        VRAM_GB=$(( VRAM_BYTES / 1024 / 1024 / 1024 ))
    else
        VRAM_GB=8 # 감지 불가 시 기본값 추정
    fi
elif lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -qi 'intel'; then
    GPU_TYPE="intel"
    GPU_NAME=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | grep -i 'intel' | head -n1 | cut -d: -f3 | xargs)
    VRAM_GB=4
else
    GPU_TYPE="cpu"
    GPU_NAME="CPU Only (No discrete GPU)"
    VRAM_GB=0
fi

echo -e "  • ${BLUE}GPU${NC}: $GPU_NAME"
echo -e "  • ${BLUE}VRAM${NC}: ${VRAM_GB} GB (가속 모드: ${PURPLE}${GPU_TYPE^^}${NC})"

# 1-3. 하드웨어 티어(Tier) 판별
if [ "$VRAM_GB" -ge 14 ]; then
    HW_TIER=1
    TIER_DESC="High-End (16GB+ VRAM) -> [주모델: Qwen 3.8 27B] & 16K 컨텍스트"
    RECOMMENDED_MAIN="qwen3.8:27b"
    RECOMMENDED_AGENT="qwen3.8:27b"
    RECOMMENDED_REASONING="qwq:32b"
    NUM_CTX=16384
elif [ "$VRAM_GB" -ge 7 ]; then
    HW_TIER=2
    TIER_DESC="Mid-Range (8GB~12GB VRAM) -> [주모델: Qwen 2.5 7B/14B] & 8K 컨텍스트"
    RECOMMENDED_MAIN="qwen2.5:7b"
    RECOMMENDED_AGENT="qwen2.5:14b"
    RECOMMENDED_REASONING="deepseek-r1:8b"
    NUM_CTX=8192
else
    HW_TIER=3
    TIER_DESC="Entry/CPU Mode (<8GB VRAM) -> 3B/7B 모델 & 4K 컨텍스트"
    RECOMMENDED_MAIN="qwen2.5:3b"
    RECOMMENDED_AGENT="qwen2.5:7b"
    RECOMMENDED_REASONING="deepseek-r1:7b"
    NUM_CTX=4096
fi

echo -e "  • ${GREEN}하드웨어 최적화 프로필${NC}: [Tier $HW_TIER] $TIER_DESC"

# ==============================================================================
# [단계 2] OS별 패키지 및 Ollama 가속 엔진 설치
# ==============================================================================
echo -e "\n${YELLOW}[2/6] OS 및 GPU 가속에 맞는 Ollama 엔진 설치 중...${NC}"

if command -v pacman &>/dev/null; then
    echo -e "  • Arch Linux 계열 패키지 관리자(pacman) 감지됨"
    sudo pacman -S --needed --noconfirm python-pip curl git base-devel lm_sensors pciutils
    
    case "$GPU_TYPE" in
        nvidia)
            echo -e "  • NVIDIA CUDA 가속 엔진(ollama-cuda) 설치"
            sudo pacman -S --needed --noconfirm ollama-cuda
            ;;
        amd)
            echo -e "  • AMD ROCm 가속 엔진(ollama-rocm) 설치"
            sudo pacman -S --needed --noconfirm ollama-rocm || sudo pacman -S --needed --noconfirm ollama
            ;;
        *)
            echo -e "  • 표준 Ollama 엔진 설치"
            sudo pacman -S --needed --noconfirm ollama
            ;;
    esac
else
    echo -e "  • 일반 리눅스 환경: 공식 Ollama 올인원 설치 스크립트 실행"
    curl -fsSL https://ollama.com/install.sh | sh
fi

# ==============================================================================
# [단계 3] Ollama 0초 VRAM 즉시 반환(keep_alive=0) 서비스 최적화
# ==============================================================================
echo -e "\n${YELLOW}[3/6] Ollama 0초 VRAM 즉시 회수(keep_alive=0) 서비스 구성 중...${NC}"

sudo mkdir -p /etc/systemd/system/ollama.service.d
OVERRIDE_CONF="/etc/systemd/system/ollama.service.d/override.conf"

sudo bash -c "cat << EOF > $OVERRIDE_CONF
[Service]
Environment=\"OLLAMA_KEEP_ALIVE=0\"
Environment=\"OLLAMA_NUM_PARALLEL=1\"
EOF"

if [ "$GPU_TYPE" = "nvidia" ]; then
    sudo bash -c "echo 'Environment=\"CUDA_VISIBLE_DEVICES=0\"' >> $OVERRIDE_CONF"
fi

sudo systemctl daemon-reload
sudo systemctl enable --now ollama.service
sleep 2

# ==============================================================================
# [단계 4] 파이썬 AI/RAG 연동 라이브러리 설치
# ==============================================================================
echo -e "\n${YELLOW}[4/6] 파이썬 의존성 패키지(ollama, duckduckgo-search) 설치 중...${NC}"
pip install --break-system-packages --upgrade ollama duckduckgo-search ddgs 2>/dev/null || pip install --upgrade ollama duckduckgo-search ddgs

# ==============================================================================
# [단계 5] 하드웨어 티어별 최적 모델 다운로드 및 빌드
# ==============================================================================
echo -e "\n${YELLOW}[5/6] 하드웨어 사양에 맞춘 최적 LLM 모델 구성 중...${NC}"

MODEL_DIR="$HOME/.local/share/ollama_custom"
mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"

if [ "$HW_TIER" -eq 1 ]; then
    echo -e "  • ${GREEN}[주모델] Qwen 3.8 27B 모델 풀링 중 (최우선 메인 엔진)...${NC}"
    ollama pull qwen3.8:27b 2>/dev/null || ollama pull qwen2.5:32b 2>/dev/null || true
    ollama pull qwq:32b 2>/dev/null || true

    GGUF_FILE="$MODEL_DIR/Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf"
    if [ ! -f "$GGUF_FILE" ]; then
        echo -e "  • [보조 모델] Qwen 2.5 14B Uncensored 다운로드 중 (약 8.98GB)..."
        curl -L --progress-bar -o "$GGUF_FILE" "https://huggingface.co/mradermacher/Qwen2.5-14B-Instruct-abliterated-v2-GGUF/resolve/main/Qwen2.5-14B-Instruct-abliterated-v2.Q4_K_M.gguf"
    fi

    cat << EOF > Modelfile.custom
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
PARAMETER num_ctx $NUM_CTX
EOF
    ollama create qwen2.5-uncensored -f Modelfile.custom

elif [ "$HW_TIER" -eq 2 ]; then
    echo -e "  • 8GB~12GB VRAM 최적화 모델 풀링 중 (Qwen 2.5 7B / 14B)..."
    ollama pull qwen2.5:7b
    ollama pull qwen2.5:14b 2>/dev/null || true
    ollama pull deepseek-r1:8b 2>/dev/null || true
    # qwen2.5-uncensored 이름으로 7B 에일리어스 생성
    ollama cp qwen2.5:7b qwen2.5-uncensored 2>/dev/null || true

else
    echo -e "  • 경량/CPU 최적화 모델 풀링 중 (Qwen 2.5 3B / 7B)..."
    ollama pull qwen2.5:3b
    ollama pull qwen2.5:7b 2>/dev/null || true
    ollama pull deepseek-r1:7b 2>/dev/null || true
    ollama cp qwen2.5:3b qwen2.5-uncensored 2>/dev/null || true
fi

# ==============================================================================
# [단계 6] 전용 동적 CLI 스위트 (~/.local/bin) 구축
# ==============================================================================
echo -e "\n${YELLOW}[6/6] 전용 동적 CLI 도구군 (~/.local/bin/{ai, ask, askweb, asksys, qwq}) 배포 중...${NC}"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# 6-1. ai (동적 하드웨어 감지 ReAct 에이전트)
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

        # 대용량 출력 축약 가드 (Head 1,000 + Tail 2,500 보존)
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

def get_system_hardware_info() -> str:
    info_lines = []
    try:
        os_name = "Linux"
        if os.path.exists("/etc/os-release"):
            with open("/etc/os-release") as f:
                for line in f:
                    if line.startswith("PRETTY_NAME="):
                        os_name = line.split("=", 1)[1].strip().strip('"')
                        break
        kernel = subprocess.check_output("uname -r", shell=True, text=True).strip()
        desktop = os.environ.get("XDG_CURRENT_DESKTOP") or os.environ.get("DESKTOP_SESSION") or "Wayland/X11"
        info_lines.append(f"- OS: {os_name} (Kernel {kernel}) | Session: {desktop}")
    except Exception:
        info_lines.append("- OS: Linux")

    try:
        cpu = subprocess.check_output("lscpu 2>/dev/null | grep 'Model name:' | sed 's/Model name:[ \t]*//'", shell=True, text=True).strip()
        if not cpu:
            cpu = subprocess.check_output("grep -m1 'model name' /proc/cpuinfo | cut -d: -f2", shell=True, text=True).strip()
        if cpu:
            info_lines.append(f"- CPU: {cpu}")
    except Exception:
        pass

    try:
        gpu_info = ""
        nv_out = subprocess.run("nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null", shell=True, stdout=subprocess.PIPE, text=True)
        if nv_out.returncode == 0 and nv_out.stdout.strip():
            g_list = []
            for g in nv_out.stdout.strip().split("\n"):
                parts = [p.strip() for p in g.split(",")]
                if len(parts) >= 2:
                    vram_gb = round(float(parts[1]) / 1024, 1)
                    g_list.append(f"NVIDIA {parts[0]} ({vram_gb}GB VRAM)")
            gpu_info = ", ".join(g_list)
        
        if not gpu_info:
            lspci_out = subprocess.check_output("lspci 2>/dev/null | grep -iE 'vga|3d|display' | cut -d: -f3", shell=True, text=True).strip()
            if lspci_out:
                gpu_info = lspci_out.replace("\n", ", ")
        
        if gpu_info:
            info_lines.append(f"- GPU: {gpu_info.strip()}")
        else:
            info_lines.append("- GPU: Integrated / CPU Only")
    except Exception:
        pass

    return "\n".join(info_lines)

def get_optimal_context_size() -> int:
    try:
        nv_out = subprocess.run("nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null", shell=True, stdout=subprocess.PIPE, text=True)
        if nv_out.returncode == 0 and nv_out.stdout.strip():
            vram_mb = float(nv_out.stdout.strip().split("\n")[0])
            if vram_mb >= 14000:
                return 16384
            elif vram_mb >= 7500:
                return 8192
    except Exception:
        pass
    return 4096

def build_system_prompt() -> str:
    hw_info = get_system_hardware_info()
    return f"""당신은 사용자의 호스트 시스템을 완전히 제어할 수 있는 자율형 AI 수석 엔지니어 에이전트(Autonomous Agent)입니다.

[실시간 감지된 호스트 시스템 환경]
{hw_info}

[자율 에이전트 행동 수칙]
1. 사용자가 하드웨어 상태(온도, VRAM, RAM, 디스크, 팬 속도 등)나 시스템 설정을 물어보면 절대 추측하지 말고 반드시 'run_terminal_command' 도구를 호출하여 실제 측정값을 확인한 후 답변하세요.
2. 최신 뉴스, 시세, 실시간 정보 등은 'search_the_web' 도구를 호출하여 최신 웹 정보를 수집한 후 답변하세요.
3. 필요한 경우 여러 도구를 연속으로 호출하여 문제를 해결할 수 있습니다.
4. 모든 최종 답변은 유려하고 명쾌한 한국어로 작성하며 핵심 근거를 제시하세요."""

def run_agent_turn(client, model, messages):
    max_loops = 6
    loop_count = 0
    ctx_size = get_optimal_context_size()

    while loop_count < max_loops:
        loop_count += 1
        
        try:
            response = client.chat(
                model=model,
                messages=messages,
                tools=TOOLS,
                options={
                    'temperature': 0.3,
                    'num_ctx': ctx_size
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
    system_prompt = build_system_prompt()
    
    # 설치된 모델 자동 탐색 및 최적 모델 Fallback
    target_model = 'qwen3.8:27b'
    try:
        client.show(target_model)
    except Exception:
        target_model = 'qwen2.5:32b'
        try:
            client.show(target_model)
        except Exception:
            target_model = 'qwen2.5-uncensored'
            try:
                client.show(target_model)
            except Exception:
                target_model = 'qwen2.5:14b'
                try:
                    client.show(target_model)
                except Exception:
                    target_model = 'qwen2.5:7b'

    if len(sys.argv) > 1:
        user_prompt = " ".join(sys.argv[1:])
        messages = [
            {'role': 'system', 'content': system_prompt},
            {'role': 'user', 'content': user_prompt}
        ]
        print(f"\033[0;36m🤖 [자율형 에이전트 가동 (모델: {target_model})]\033[0m")
        print(f"👤 사용자 요청: {user_prompt}\n")
        answer = run_agent_turn(client, target_model, messages)
        print(f"\n\033[0;32m🤖 [최종 답변]:\033[0m\n{answer}")
        return

    print(f"\033[0;36m====================================================\033[0m")
    print(f"\033[0;32m  🚀 완전 자율형 로컬 AI 에이전트 (ai) 시작  \033[0m")
    print(f"\033[0;33m  (PC 제어, 하드웨어 점검, 웹 검색, 코딩을 스스로 수행합니다)\033[0m")
    print(f"\033[0;36m  종료: /bye 또는 exit | 초기화: /clear\033[0m")
    print(f"\033[0;36m====================================================\033[0m\n")

    history = [{'role': 'system', 'content': system_prompt}]

    while True:
        try:
            user_input = input("\033[1;34mAI >>> \033[0m").strip()
            if not user_input:
                continue
            if user_input in ['/bye', 'exit', 'quit']:
                print("\033[0;33m자율형 에이전트를 종료합니다.\033[0m")
                break
            if user_input in ['/clear', 'clear']:
                history = [{'role': 'system', 'content': system_prompt}]
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

# 6-2. ask (단발 및 파이프라인)
cat << 'ASK_EOF' > "$BIN_DIR/ask"
#!/usr/bin/env bash
# 사용 가능한 기본 모델 자동 탐색
MODEL="qwen2.5-uncensored"
if ! ollama show "$MODEL" &>/dev/null; then
    MODEL="qwen2.5:7b"
    if ! ollama show "$MODEL" &>/dev/null; then
        MODEL="qwen2.5:3b"
    fi
fi

if [ -p /dev/stdin ]; then
    STDIN_DATA=$(cat)
    if [ $# -gt 0 ]; then
        PROMPT="$*\n\n[입력 데이터]:\n$STDIN_DATA"
    else
        PROMPT="$STDIN_DATA"
    fi
    ollama run "$MODEL" "$PROMPT"
else
    if [ $# -gt 0 ]; then
        ollama run "$MODEL" "$*"
    else
        ollama run "$MODEL"
    fi
fi
ASK_EOF
chmod +x "$BIN_DIR/ask"

# 6-3. askweb (Google RAG 검색)
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

    client = ollama.Client()
    target_model = 'qwen2.5-uncensored'
    try:
        client.show(target_model)
    except Exception:
        target_model = 'qwen2.5:7b'

    res = client.chat(
        model=target_model,
        messages=[{'role': 'user', 'content': prompt}],
        options={'temperature': 0.4}
    )
    print(f"\033[0;32m🤖 [로컬 AI 답변]:\033[0m\n{res['message']['content']}")

if __name__ == '__main__':
    main()
ASKWEB_EOF
chmod +x "$BIN_DIR/askweb"

# 6-4. asksys (하드웨어 진단)
cat << 'ASKSYS_EOF' > "$BIN_DIR/asksys"
#!/usr/bin/env bash
USER_QUERY="$*"
if [ -z "$USER_QUERY" ]; then
    USER_QUERY="현재 시스템 하드웨어 상태(온도, VRAM, RAM, CPU, 디스크, 실패한 서비스, 커널 에러)를 종합적으로 분석하고 문제 여부를 진단해줘."
fi

echo -e "\033[0;34m⚡ [시스템 하드웨어 및 커널 상태 초고속 수집 중...]\033[0m"

SYS_INFO="[1. GPU 상태]\n$(nvidia-smi 2>/dev/null || rocm-smi 2>/dev/null || lspci 2>/dev/null | grep -iE 'vga|3d|display' || echo 'N/A')\n\n"
SYS_INFO+="[2. CPU/온도 센서]\n$(sensors 2>/dev/null | grep -E 'Tctl|Tdie|temp1|Package|Core' || sensors 2>/dev/null | head -20 || echo '센서 미지원')\n\n"
SYS_INFO+="[3. 메모리 상태]\n$(free -h)\n\n"
SYS_INFO+="[4. 디스크 용량]\n$(df -h / /home 2>/dev/null || df -h /)\n\n"
SYS_INFO+="[5. 실패한 systemd 서비스]\n$(systemctl --failed --no-pager 2>/dev/null | head -10 || echo '없음')\n\n"
SYS_INFO+="[6. 최근 커널 에러 로그]\n$(dmesg --level=err,warn 2>/dev/null | tail -15 || echo '에러 없음')"

PROMPT="당신은 리눅스 시스템 전문 수석 엔지니어입니다.
아래 실시간 시스템 하드웨어 덤프 데이터를 정밀 분석하여 사용자 질문에 대해 명쾌한 종합 진단 리포트를 작성하세요.

$SYS_INFO

[사용자 요청]
$USER_QUERY"

MODEL="qwen2.5-uncensored"
if ! ollama show "$MODEL" &>/dev/null; then
    MODEL="qwen2.5:7b"
fi

echo -e "\033[0;32m🤖 [수석 엔지니어 AI 진단 리포트 생성 중...]\033[0m\n"
ollama run "$MODEL" "$PROMPT"
ASKSYS_EOF
chmod +x "$BIN_DIR/asksys"

# 6-5. qwq / askqwq (단계별 추론)
cat << 'QWQ_EOF' > "$BIN_DIR/askqwq"
#!/usr/bin/env bash
MODEL="qwq:32b"
if ! ollama show "$MODEL" &>/dev/null; then
    MODEL="deepseek-r1:8b"
    if ! ollama show "$MODEL" &>/dev/null; then
        MODEL="deepseek-r1:7b"
    fi
fi

if [ -p /dev/stdin ]; then
    STDIN_DATA=$(cat)
    if [ $# -gt 0 ]; then
        PROMPT="$*\n\n[입력 데이터]:\n$STDIN_DATA"
    else
        PROMPT="$STDIN_DATA"
    fi
    ollama run "$MODEL" "$PROMPT"
else
    if [ $# -gt 0 ]; then
        ollama run "$MODEL" "$*"
    else
        ollama run "$MODEL"
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
echo -e "${GREEN}  🎉 범용 로컬 LLM & 자율형 CLI 에이전트 구축이 완료되었습니다!  ${NC}"
echo -e "${GREEN}================================================================${NC}"
echo -e "${CYAN}감지된 하드웨어 프로필:${NC} [Tier $HW_TIER] $TIER_DESC"
echo -e "${CYAN}터미널에서 바로 사용할 수 있는 명령어:${NC}"
echo -e "  - ${PURPLE}ai${NC}     : 완전 자율형 AI 에이전트 (터미널 제어 + 구글 검색)"
echo -e "  - ${PURPLE}ask${NC}    : 고속 무검열 로컬 대화 및 파이프라인 질의"
echo -e "  - ${PURPLE}askweb${NC} : 실시간 Google/웹 검색 RAG 브리핑"
echo -e "  - ${PURPLE}asksys${NC} : 1초 하드웨어 센서 및 커널 진단 리포터"
echo -e "  - ${PURPLE}qwq${NC}    : 단계별 심층 추론 모델"
echo -e "\n새 터미널을 열거나 ${YELLOW}source ~/.bashrc${NC} 를 실행하여 시작하세요.\n"
