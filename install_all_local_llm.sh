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

    echo -e "  • ${GREEN}[전역 에이전트 모델] smart-qwen (2026년 기준 내장) 빌드 중...${NC}"
    cat << 'SMART_EOF' > Modelfile.smart-qwen
FROM qwen3.8:27b
PARAMETER temperature 0.3
PARAMETER top_p 0.9
PARAMETER num_ctx 8192
SYSTEM """당신은 최고 수준의 지능, 논리적 사고 능력, 리눅스 시스템 전문성을 갖춘 올인원(All-in-One) AI 에이전트입니다.
사용자의 질문과 요청을 완벽하게 이해하고 가장 정확하며 최적화된 결과를 제공해야 합니다.

[시간 인식 및 기준 시점 원칙]
- 현재 실제 연도는 2026년입니다.
- '최근', '올해', '최신 동향', '뉴스' 등의 정보를 언급하거나 검색 키워드를 생성할 때, 과거(2024~2025년)가 아닌 반드시 현재 시점인 2026년을 기준으로 사고하고 작성하세요.

[핵심 행동 지침]
1. 단계별 심층 추론 (Step-by-Step Reasoning): 대답하기 전 논리적 검증 수행
2. 리눅스 & 시스템 전문가 지식 (Arch Linux / CachyOS 기반): 안전하고 실행 가능한 Shell 코드 작성
3. 한국어 응답 및 뛰어난 가독성: 표, 불릿 포인트, 코드 블록을 활용한 명쾌한 한국어 답변
4. 환각(Hallucination) 방지 및 솔직함: 불확실한 정보 솔직 명시
"""
SMART_EOF
    ollama create smart-qwen -f Modelfile.smart-qwen 2>/dev/null || true

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
import time

# 경고 무음 처리
warnings.simplefilter("ignore")
warnings.filterwarnings("ignore")
os.environ["PYTHONWARNINGS"] = "ignore"

def dummy_showwarning(*args, **kwargs):
    pass
warnings.showwarning = dummy_showwarning

import ollama

# ==============================================================================
# 🧠 대화 세션 영구 기억 (Persistent Session Memory)
# ==============================================================================
SESSION_FILE = os.path.expanduser("~/.cache/ai_agent/session.json")
SESSION_TIMEOUT_SEC = 3600  # 1시간 동안 미사용 시 자동 리셋
MAX_HISTORY_TURNS = 5       # 기억할 최대 대화 쌍 (사용자 질문 + AI 최종 답변)

def load_session_history():
    """디스크에서 최근 대화 세션을 불러옵니다."""
    if not os.path.exists(SESSION_FILE):
        return []
    try:
        with open(SESSION_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        last_time = data.get("timestamp", 0)
        if time.time() - last_time > SESSION_TIMEOUT_SEC:
            return []
        return data.get("messages", [])
    except Exception:
        return []

def save_session_history(dialogue_history):
    """최근 대화 기록을 디스크에 영구 저장합니다."""
    try:
        os.makedirs(os.path.dirname(SESSION_FILE), exist_ok=True)
        filtered = []
        for m in dialogue_history:
            if m.get("role") in ["user", "assistant"] and m.get("content"):
                filtered.append({"role": m["role"], "content": m["content"]})
        
        max_msgs = MAX_HISTORY_TURNS * 2
        if len(filtered) > max_msgs:
            filtered = filtered[-max_msgs:]

        data = {
            "timestamp": time.time(),
            "messages": filtered
        }
        with open(SESSION_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception:
        pass

def clear_session_history():
    """대화 기억을 초기화합니다."""
    if os.path.exists(SESSION_FILE):
        try:
            os.remove(SESSION_FILE)
        except Exception:
            pass

# ==============================================================================
# 도구(Tools) 정의
# ==============================================================================

def tool_bash(command: str) -> str:
    """리눅스 셸 명령어를 실행하고 결과를 반환합니다."""
    # 위험 명령어 사전 차단
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
            result += f"
[stderr]: {err}"

        if not result:
            return "(출력 없음, 정상 실행됨)"

        # 대용량 출력 축약 (컨텍스트 윈도우 보호 및 user 쿼리 유실 방지)
        max_len = 3500
        if len(result) > max_len:
            head_len = 1000
            tail_len = 2500
            result = f"{result[:head_len]}

... [중략: 총 {len(result)}자 중 {len(result) - head_len - tail_len}자 생략됨] ...

{result[-tail_len:]}"

        return result
    except subprocess.TimeoutExpired:
        return "❌ [오류] 명령어 실행 시간 초과 (15초)"
    except Exception as e:
        return f"❌ [실행 실패]: {e}"

def get_current_time_context():
    """실시간 현재 시스템 일시 및 기준 연도를 감지합니다."""
    try:
        now_str = subprocess.getoutput("date '+%Y년 %m월 %d일 (%a) %H:%M:%S' 2>/dev/null") or "2026년"
        current_year = subprocess.getoutput("date '+%Y' 2>/dev/null") or "2026"
    except Exception:
        import datetime
        now = datetime.datetime.now()
        now_str = now.strftime("%Y년 %m월 %d일 %H:%M:%S")
        current_year = str(now.year)
    return now_str, current_year

def tool_web_search(query: str):
    """Google 웹 검색을 통해 최신 실시간 정보를 수집합니다."""
    now_str, current_year = get_current_time_context()

    # 모델이 학습 컷오프(2024~2025년) 관성으로 인해 과거 연도(2024, 2025)로 검색하는 경우 현재 연도(2026)로 스마트 자동 보정
    refined_query = re.sub(r'202[45]', current_year, query)

    results = []
    # 1. Google HTTP 파서
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept-Language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7"
        }
        url = f"https://www.google.com/search?q={urllib.parse.quote(refined_query)}&hl=ko&gl=kr&num=4"
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
                raw = list(ddgs.text(refined_query, region="kr-kr", max_results=4))
                for i, r in enumerate(raw):
                    results.append(f"[{i+1}] {r.get('title', '')} - {r.get('body', '')}")
        except Exception:
            pass

    content = "
".join(results) if results else "검색 결과 없음"
    return content, refined_query

# ==============================================================================
# Ollama 공식 Tool Definitions
# ==============================================================================

def get_tools():
    now_str, current_year = get_current_time_context()
    return [
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
                'description': f'실시간 인터넷 웹(Google)을 검색하여 최신 뉴스, 날씨, 시세, 기술 동향, 패치노트 등을 수집합니다. [중요] 현실 세계의 현재 실제 연도는 {current_year}년입니다. "올해", "최근", "최신" 관련 질의나 시점 미지정 검색 시 반드시 과거(2024~2025년)가 아닌 {current_year}년을 기준으로 검색 키워드를 작성하세요.',
                'parameters': {
                    'type': 'object',
                    'properties': {
                        'query': {
                            'type': 'string',
                            'description': f'검색할 키워드 또는 질의어 (최신 정보 검색 시 반드시 {current_year}년 기준 적용)'
                        }
                    },
                    'required': ['query']
                }
            }
        }
    ]

def get_system_hardware_info() -> str:
    """호스트 PC의 OS, CPU, GPU, VRAM 정보를 0.01초 만에 실시간 감지합니다."""
    info_lines = []
    
    # 1. OS 및 세션 정보
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

    # 2. CPU
    try:
        cpu = subprocess.check_output("lscpu 2>/dev/null | grep 'Model name:' | sed 's/Model name:[ 	]*//'", shell=True, text=True).strip()
        if not cpu:
            cpu = subprocess.check_output("grep -m1 'model name' /proc/cpuinfo | cut -d: -f2", shell=True, text=True).strip()
        if cpu:
            info_lines.append(f"- CPU: {cpu}")
    except Exception:
        pass

    # 3. GPU & VRAM
    try:
        gpu_info = ""
        nv_out = subprocess.run("nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null", shell=True, stdout=subprocess.PIPE, text=True)
        if nv_out.returncode == 0 and nv_out.stdout.strip():
            g_list = []
            for g in nv_out.stdout.strip().split("
"):
                parts = [p.strip() for p in g.split(",")]
                if len(parts) >= 2:
                    vram_gb = round(float(parts[1]) / 1024, 1)
                    g_list.append(f"NVIDIA {parts[0]} ({vram_gb}GB VRAM)")
            gpu_info = ", ".join(g_list)
        
        if not gpu_info:
            lspci_out = subprocess.check_output("lspci 2>/dev/null | grep -iE 'vga|3d|display' | cut -d: -f3", shell=True, text=True).strip()
            if lspci_out:
                gpu_info = lspci_out.replace("
", ", ")
        
        if gpu_info:
            info_lines.append(f"- GPU: {gpu_info.strip()}")
        else:
            info_lines.append("- GPU: Integrated / CPU Only")
    except Exception:
        pass

    return "
".join(info_lines)

def get_optimal_context_size() -> int:
    """GPU VRAM 용량에 맞춰 최적의 num_ctx(컨텍스트 윈도우)를 자동 산출합니다."""
    try:
        nv_out = subprocess.run("nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null", shell=True, stdout=subprocess.PIPE, text=True)
        if nv_out.returncode == 0 and nv_out.stdout.strip():
            vram_mb = float(nv_out.stdout.strip().split("
")[0])
            if vram_mb >= 14000:  # 16GB+ VRAM
                return 16384
            elif vram_mb >= 7500: # 8GB~12GB VRAM
                return 8192
    except Exception:
        pass
    return 4096  # 저사양 또는 CPU 환경 기본값

def build_system_prompt() -> str:
    hw_info = get_system_hardware_info()
    now_str, current_year = get_current_time_context()
    return f"""당신은 사용자의 호스트 시스템을 완전히 제어할 수 있는 자율형 AI 수석 엔지니어 에이전트(Autonomous Agent)입니다.

[실시간 현재 일시 및 시간 기준 절대 원칙]
- 현재 실제 일시: {now_str} (기준 연도: {current_year}년)
- 사전 학습 데이터 마감(2024~2025년)과 상관없이, 현재 현실 세계의 실제 연도는 {current_year}년입니다.
- '올해', '최근', '최신 동향', '뉴스', '현재 상황' 등을 분석하거나 언급할 때 절대로 2024년이나 2025년을 현재로 착각하지 마세요.
- Google 웹 검색 키워드를 작성할 때와 검색된 결과를 요약할 때 모든 기준 시점은 반드시 {current_year}년입니다.

[실시간 감지된 호스트 시스템 환경]
{hw_info}

[자율 에이전트 행동 수칙]
1. 사용자가 하드웨어 상태(온도, VRAM, RAM, 디스크, 팬 속도 등)나 시스템 설정을 물어보면 절대 추측해서 답하지 말고, 반드시 'run_terminal_command' 도구를 호출하여 실제 측정값을 확인한 후 답변하세요.
2. 사용자가 최신 뉴스, 시세, 게임 패치노트, 실시간 정보 등을 물어보면 'search_the_web' 도구를 호출하여 {current_year}년 기준 최신 웹 정보를 수집한 후 답변하세요.
3. 필요한 경우 여러 도구를 연속으로 호출하여 문제를 해결할 수 있습니다.
4. 모든 최종 답변은 유려하고 명쾌한 한국어로 작성하며 핵심 근거를 제시하세요."""

def run_agent_turn(client, model, messages):
    """자율형 ReAct 루프 실행 (도구 호출 -> 실행 -> 최종 답변)"""
    max_loops = 6
    loop_count = 0
    ctx_size = get_optimal_context_size()
    tools = get_tools()
    now_str, current_year = get_current_time_context()

    while loop_count < max_loops:
        loop_count += 1
        
        try:
            response = client.chat(
                model=model,
                messages=messages,
                tools=tools,
                options={
                    'temperature': 0.3,
                    'num_ctx': ctx_size  # 하드웨어 사양에 맞춰 동적으로 계산된 컨텍스트 크기 적용
                },
                keep_alive=0
            )
        except Exception as e:
            return f"❌ [Ollama 응답 처리 오류]: {e}
(도구 실행 결과량이 너무 많거나 모델 템플릿에서 오류가 발생했습니다.)"

        message = response['message']
        messages.append(message)

        # 도구 호출(Tool Calls)이 없는 경우 -> 최종 답변 완료
        if not message.get('tool_calls'):
            return message.get('content', '')

        # 도구 호출이 있는 경우 -> 실행 후 결과 피드백
        for tool_call in message['tool_calls']:
            fn_name = tool_call['function']['name']
            fn_args = tool_call['function']['arguments']

            print(f"[0;35m⚡ [자율 에이전트 도구 실행][0m: {fn_name}")
            
            tool_output = ""
            if fn_name == 'run_terminal_command':
                cmd = fn_args.get('command', '')
                print(f"  [0;34m$ {cmd}[0m")
                tool_output = tool_bash(cmd)
                # 실행 결과 미리보기 (일부 축약)
                preview = tool_output[:200] + "..." if len(tool_output) > 200 else tool_output
                print(f"  [0;32m↳ 결과 수집 완료 ({len(tool_output)}자)[0m")
            
            elif fn_name == 'search_the_web':
                query = fn_args.get('query', '')
                tool_output, refined_query = tool_web_search(query)
                if refined_query != query:
                    print(f"  [0;34m🔍 구글 검색: {query} ➔ {refined_query} (기준 연도 {current_year}년 자동 보정)[0m")
                else:
                    print(f"  [0;34m🔍 구글 검색: {query} (기준 연도 {current_year}년)[0m")
                print(f"  [0;32m↳ 웹 검색 완료[0m")

            # 도구 실행 결과를 대화 문맥에 추가
            messages.append({
                'role': 'tool',
                'content': str(tool_output)
            })

    return "❌ 도구 실행 루프 한도 초과"

def main():
    client = ollama.Client()
    system_prompt = build_system_prompt()
    
    # 설치된 모델 자동 탐색 및 최적 모델 Fallback (2026년 최적화된 smart-qwen 최우선)
    target_model = 'smart-qwen'
    try:
        client.show(target_model)
    except Exception:
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

    # 1. 단발성 인수 실행 (예: ai "내 그래픽카드 온도 확인하고 오늘 날씨 알려줘")
    if len(sys.argv) > 1:
        user_prompt = " ".join(sys.argv[1:])

        # 기억 초기화 명령어 지원
        if user_prompt.lower() in ["clear", "reset", "/clear", "/reset", "초기화", "기억삭제"]:
            clear_session_history()
            print("[0;32m🧹 [대화 기억 초기화 완료][0m 이전 세션 대화 기록이 모두 삭제되었습니다.")
            return

        saved_history = load_session_history()
        messages = [{'role': 'system', 'content': system_prompt}]
        
        if saved_history:
            turns = len(saved_history) // 2
            print(f"[0;35m🧠 [이전 대화 기억 {turns}개 연속 유지 중][0m [0;33m(기억 초기화: ai clear)[0m")
            messages.extend(saved_history)

        messages.append({'role': 'user', 'content': user_prompt})
        print(f"[0;36m🤖 [자율형 에이전트 가동 (모델: {target_model})][0m")
        print(f"👤 사용자 요청: {user_prompt}
")
        answer = run_agent_turn(client, target_model, messages)
        print(f"
[0;32m🤖 [최종 답변]:[0m
{answer}")

        # 이번 턴의 응답을 세션에 누적 저장
        save_session_history(messages)
        return

    # 2. 대화형 인터랙티브 REPL 모드
    print(f"[0;36m====================================================[0m")
    print(f"[0;32m  🚀 완전 자율형 로컬 AI 에이전트 (ai) 시작  [0m")
    print(f"[0;33m  (PC 제어, 하드웨어 점검, 웹 검색, 코딩을 스스로 수행합니다)[0m")
    print(f"[0;36m  종료: /bye 또는 exit | 초기화: /clear[0m")
    print(f"[0;36m====================================================[0m
")

    saved_history = load_session_history()
    history = [{'role': 'system', 'content': system_prompt}]
    if saved_history:
        history.extend(saved_history)
        turns = len(saved_history) // 2
        print(f"[0;35m🧠 [이전 세션 대화 기억 {turns}개 불러옴] (초기화: /clear)[0m
")

    while True:
        try:
            user_input = input("[1;34mAI >>> [0m").strip()
            if not user_input:
                continue
            if user_input in ['/bye', 'exit', 'quit']:
                print("[0;33m자율형 에이전트를 종료합니다.[0m")
                break
            if user_input in ['/clear', 'clear']:
                clear_session_history()
                history = [{'role': 'system', 'content': system_prompt}]
                print("[0;32m대화 기억이 초기화되었습니다.[0m")
                continue

            history.append({'role': 'user', 'content': user_input})
            answer = run_agent_turn(client, target_model, history)
            print(f"
[0;32m🤖 [답변]:[0m
{answer}
")
            save_session_history(history)

        except (KeyboardInterrupt, EOFError):
            print("
[0;33m자율형 에이전트를 종료합니다.[0m")
            break

if __name__ == '__main__':
    main()
AI_EOF
chmod +x "$BIN_DIR/ai"

# 6-2. ask (단발 및 파이프라인)
cat << 'ASK_EOF' > "$BIN_DIR/ask"
#!/usr/bin/env bash

# smart-qwen (2026년 기준 내장) 우선, 없으면 qwen3.8:27b fallback
MODEL="smart-qwen"
if ! ollama list | grep -q "$MODEL"; then
    MODEL="qwen3.8:27b"
    if ! ollama list | grep -q "$MODEL"; then
        MODEL="qwen2.5-32b-uncensored"
        if ! ollama list | grep -q "$MODEL"; then
            MODEL="qwen2.5-uncensored"
        fi
    fi
fi

# 1. 파이프(|) 입력이 들어온 경우 (표준 입력 감지)
if [ ! -t 0 ]; then
    STDIN_DATA=$(cat)
    USER_QUERY="$*"
    if [ -z "$USER_QUERY" ]; then
        USER_QUERY="제공된 내용을 분석하고 핵심을 한국어로 요약해줘."
    fi
    
    PROMPT="[전달된 데이터/로그/코드]
$STDIN_DATA

[요청 사항]
$USER_QUERY"
    echo -e "$PROMPT" | ollama run "$MODEL"
else
    # 2. 파이프 없이 그냥 'ask' 실행한 경우 (대화형 모드)
    if [ -n "$*" ]; then
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

# 전역 모든 경고 완벽 무음 처리
warnings.simplefilter("ignore")
warnings.filterwarnings("ignore")
os.environ["PYTHONWARNINGS"] = "ignore"

# 표준 경고 출력 핸들러 무력화
def dummy_showwarning(*args, **kwargs):
    pass
warnings.showwarning = dummy_showwarning

import json
import urllib.request
import urllib.parse
import re
import ollama

def search_google(query, max_results=4):
    """Google 한국어 웹 검색 엔진"""
    results = []
    
    # 1. googlesearch-python 라이브러리 시도
    try:
        from googlesearch import search
        raw = list(search(query, num_results=max_results, lang="ko", advanced=True))
        for r in raw:
            results.append({
                "title": r.title if hasattr(r, 'title') else "",
                "body": r.description if hasattr(r, 'description') else "",
                "url": r.url if hasattr(r, 'url') else ""
            })
        if results:
            return results, "Google (Python Engine)"
    except Exception:
        pass

    # 2. Google Direct HTTP 파서 (User-Agent 브라우저 위장 및 한국어 로케일)
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept-Language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8"
        }
        encoded_query = urllib.parse.quote(query)
        url = f"https://www.google.com/search?q={encoded_query}&hl=ko&gl=kr&num={max_results + 2}"
        
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as response:
            html = response.read().decode("utf-8", errors="ignore")
            titles = re.findall(r'<h3[^>]*>(.*?)</h3>', html)
            snippets = re.findall(r'<div[^>]+class="[^"]*(?:VwiC3b|yXK7lf|MUxGbd)[^"]*"[^>]*>(.*?)</div>', html)
            if not snippets:
                snippets = re.findall(r'<span class="[^"]*hgKElc[^"]*">(.*?)</span>', html)

            for i in range(min(len(titles), max_results)):
                clean_title = re.sub(r'<.*?>', '', titles[i]).strip()
                clean_body = re.sub(r'<.*?>', '', snippets[i]).strip() if i < len(snippets) else ""
                if clean_title:
                    results.append({
                        "title": clean_title,
                        "body": clean_body,
                        "url": ""
                    })
            if results:
                return results, "Google"
    except Exception:
        pass

    # 3. DuckDuckGo 백업 검색 (구글 봇 차단 시 자동 Fallback)
    try:
        try:
            from ddgs import DDGS
        except Exception:
            from duckduckgo_search import DDGS
        with DDGS() as ddgs:
            raw_results = list(ddgs.text(query, region="kr-kr", max_results=max_results))
            for r in raw_results:
                results.append({
                    "title": r.get("title", ""),
                    "body": r.get("body", ""),
                    "url": r.get("href", "")
                })
            if results:
                return results, "DuckDuckGo (Fallback)"
    except Exception:
        pass

    return results, "None"

def get_current_time_context():
    """실시간 현재 시스템 일시 및 기준 연도를 감지합니다."""
    try:
        now_str = subprocess.getoutput("date '+%Y년 %m월 %d일 (%a) %H:%M:%S' 2>/dev/null") or "2026년"
        current_year = subprocess.getoutput("date '+%Y' 2>/dev/null") or "2026"
    except Exception:
        import datetime
        now = datetime.datetime.now()
        now_str = now.strftime("%Y년 %m월 %d일 %H:%M:%S")
        current_year = str(now.year)
    return now_str, current_year

def main():
    if len(sys.argv) < 2:
        print("[0;33m사용법: askweb \"검색할 질문 내용을 입력하세요\"[0m")
        sys.exit(1)

    now_str, current_year = get_current_time_context()
    raw_query = " ".join(sys.argv[1:])

    # 과거 연도(2024, 2025) 질의를 현재 연도(2026)로 자동 보정
    query = re.sub(r'202[45]', current_year, raw_query)

    if query != raw_query:
        print(f"[0;34m🔍 [Google 실시간 검색 중...][0m: {raw_query} ➔ {query} (기준 연도 {current_year}년 자동 보정)")
    else:
        print(f"[0;34m🔍 [Google 실시간 검색 중...][0m: {query} (기준 연도: {current_year}년)")

    search_results, engine_name = search_google(query, max_results=4)

    results_text = ""
    if search_results:
        print(f"[0;32m✓ {engine_name} 검색 완료 ({len(search_results)}개 최신 정보 수집)[0m
")
        for i, r in enumerate(search_results):
            body_text = f" - {r['body']}" if r['body'] else ""
            results_text += f"
[검색 정보 {i+1}]
제목: {r['title']}{body_text}
"
    else:
        print("[0;33m⚠️ 실시간 웹 검색 결과를 가져오지 못하여 로컬 내장 지식으로 답변합니다.[0m
")

    system_prompt = (
        f"당신은 Google 실시간 최신 웹 검색 정보를 기반으로 사용자의 질문에 정확하고 상세히 답변하는 전문 AI 비서입니다.

"
        f"[실시간 현재 일시 및 시간 기준 절대 원칙]
"
        f"- 현재 실제 일시: {now_str} (기준 연도: {current_year}년)
"
        f"- 사전 학습 데이터 마감(2024~2025년)과 상관없이, 현재 현실 세계의 실제 연도는 {current_year}년입니다.
"
        f"- 사용자가 '올해', '최근', '최신 동향', '뉴스', '현재 상황' 등을 질문하거나 정보를 요약할 때 절대 과거(2024년, 2025년)를 현재로 착각하지 말고 반드시 {current_year}년을 기준으로 사고하고 답변하세요.
"
        f"- 제공된 웹 검색 결과를 최우선으로 분석하여 한국어로 알기 쉽게 정리해 주세요.
"
        f"- 검색 결과에 날짜나 구체적인 수치가 있다면 그대로 정확하게 반영하세요."
    )

    user_content = f"""[Google 실시간 최신 검색 정보 (기준 시점: {current_year}년)]
{results_text if results_text else "실시간 검색 정보 없음"}

[사용자 질문]
{query}"""

    try:
        client = ollama.Client()
        # 2026년 최적화된 smart-qwen 우선 사용, 없으면 fallback
        target_model = 'smart-qwen'
        try:
            client.show(target_model)
        except Exception:
            target_model = 'qwen3.8:27b'
            try:
                client.show(target_model)
            except Exception:
                target_model = 'qwen2.5-32b-uncensored'
                try:
                    client.show(target_model)
                except Exception:
                    target_model = 'qwen2.5-uncensored'

        # keep_alive=0 : 답변 완료 즉시 VRAM 0초 만에 완전 반환
        response = client.chat(
            model=target_model,
            messages=[
                {'role': 'system', 'content': system_prompt},
                {'role': 'user', 'content': user_content}
            ],
            options={'temperature': 0.4},
            keep_alive=0
        )
        print("[0;32m🤖 [로컬 AI 답변]:[0m
")
        print(response['message']['content'])
    except Exception as e:
        print(f"[0;31m❌ Ollama 실행 오류: {e}[0m")
        print("💡 팁: 'sudo systemctl restart ollama.service' 로 Ollama 서비스가 켜져 있는지 확인하세요.")

if __name__ == '__main__':
    main()
ASKWEB_EOF
chmod +x "$BIN_DIR/askweb"

# 6-4. asksys (하드웨어 진단)
cat << 'ASKSYS_EOF' > "$BIN_DIR/asksys"
#!/usr/bin/env -S python3 -W ignore
import sys
import os
import subprocess
import warnings

# 전역 모든 경고 완벽 무음 처리
warnings.simplefilter("ignore")
warnings.filterwarnings("ignore")
os.environ["PYTHONWARNINGS"] = "ignore"

def dummy_showwarning(*args, **kwargs):
    pass
warnings.showwarning = dummy_showwarning

import ollama

def run_cmd(cmd):
    """안전한 셸 명령어 실행 및 결과 수집"""
    try:
        res = subprocess.run(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=3
        )
        output = res.stdout.strip()
        return output if output else "정보 없음"
    except Exception as e:
        return f"수집 실패: {e}"

def collect_system_metrics():
    """Arch Linux & RTX 5070 Ti 실시간 하드웨어/OS 상태 수집"""
    metrics = {}

    # 1. OS 및 업타임
    metrics["uptime"] = run_cmd("uptime -p")
    metrics["kernel"] = run_cmd("uname -r")

    # 2. CPU 로드 및 온도
    metrics["cpu_model"] = run_cmd("lscpu | grep 'Model name' | sed 's/Model name:[ 	]*//'")
    metrics["cpu_temp"] = run_cmd("sensors 2>/dev/null | grep -E '(Tctl|Package id 0|Tccd1):' | head -n 2")
    if not metrics["cpu_temp"] or metrics["cpu_temp"] == "정보 없음":
        metrics["cpu_temp"] = run_cmd("cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -n 1 | awk '{print $1/1000 \"°C\"}'")

    # 3. GPU (NVIDIA RTX 5070 Ti) 실시간 수치
    gpu_raw = run_cmd("nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw --format=csv,noheader,nounits 2>/dev/null")
    if gpu_raw and "수집 실패" not in gpu_raw:
        parts = [p.strip() for p in gpu_raw.split(",")]
        if len(parts) >= 7:
            metrics["gpu_info"] = (
                f"모델: {parts[0]}
"
                f"온도: {parts[1]}°C | GPU 사용률: {parts[2]}% | 메모리 I/O: {parts[3]}%
"
                f"VRAM 점유율: {parts[4]}MB / {parts[5]}MB (사용률: {round(float(parts[4])/float(parts[5])*100, 1)}%)
"
                f"소비 전력: {parts[6]}W"
            )
        else:
            metrics["gpu_info"] = gpu_raw
    else:
        metrics["gpu_info"] = run_cmd("nvidia-smi 2>/dev/null | head -n 15")

    # 4. RAM & Swap 메모리
    metrics["memory"] = run_cmd("free -h | awk 'NR<=3 {print $1, $2, $3, $4, $7}'")

    # 5. 디스크 용량 (Root & Home)
    metrics["disk"] = run_cmd("df -h / /home 2>/dev/null | awk '{print $1, $2, $3, $4, $5, $6}'")

    # 6. 실패한 systemd 서비스
    failed_services = run_cmd("systemctl --failed --no-legend --no-pager 2>/dev/null")
    metrics["failed_services"] = failed_services if failed_services else "실패한 서비스 없음 (정상)"

    # 7. 최근 커널 시스템 경고/에러 로그
    dmesg_errors = run_cmd("journalctl -p 3 -xb -n 4 --no-pager 2>/dev/null | awk '{$1=$2=$3=\"\"; print $0}'")
    metrics["recent_errors"] = dmesg_errors if dmesg_errors else "최근 치명적 커널 에러 없음 (정상)"

    return metrics

def main():
    user_query = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "현재 시스템 전체 상태를 종합 진단하고 이상 유무와 개선점을 분석해줘."

    print("[0;34m🔍 [Arch Linux & RTX 5070 Ti 실시간 하드웨어/OS 점검 중...][0m")
    metrics = collect_system_metrics()

    raw_data = f"""[호스트 환경]
- OS / Kernel: Arch Linux ({metrics['kernel']}) | 업타임: {metrics['uptime']}
- CPU: {metrics['cpu_model']}
- CPU 실시간 온도: {metrics['cpu_temp']}

[GPU (NVIDIA) 실시간 상태]
{metrics['gpu_info']}

[메모리 (RAM & Swap)]
{metrics['memory']}

[디스크 용량]
{metrics['disk']}

[systemd 서비스 상태]
{metrics['failed_services']}

[최근 주요 시스템 로그]
{metrics['recent_errors']}"""

    print("[0;32m✓ 하드웨어 센서 및 시스템 메트릭 수집 완료[0m
")
    print(f"[0;36m📋 [실시간 수집된 주요 수치 요약][0m
{metrics['gpu_info']}
")

    now_str = subprocess.getoutput("date '+%Y년 %m월 %d일 (%a) %H:%M:%S' 2>/dev/null") or "2026년"
    current_year = subprocess.getoutput("date '+%Y' 2>/dev/null") or "2026"

    system_prompt = (
        f"당신은 Arch Linux 및 초고사양 하드웨어(Ryzen 9800X3D + RTX 5070 Ti) 전문 시스템 엔지니어 AI입니다. "
        f"[실시간 현재 일시: {now_str} (기준 연도: {current_year}년)] "
        f"제공된 실시간 시스템 메트릭 데이터를 기반으로 사용자의 PC 상태를 정밀하게 진단하세요.
"
        f"1. 종합 판정: [정상 🟢 / 주의 🟡 / 위험 🔴] 3단계로 명확히 판정하세요.
"
        f"2. CPU/GPU 온도, VRAM/RAM 점유율, 전력 소비, systemd 데몬 상태를 항목별로 평가하세요.
"
        f"3. 만약 이상 징후(과열, VRAM 누수, 실패한 서비스)가 발견되면 즉시 실행할 수 있는 리눅스 조치 명령어를 제시하세요.
"
        f"4. 답변은 품격 있고 명확한 한국어로 작성하세요."
    )

    user_prompt = f"""다음은 방금 내 컴퓨터에서 실시간으로 수집된 실제 하드웨어 및 OS 상태 데이터입니다:

{raw_data}

[사용자 진단 요청]
{user_query}"""

    try:
        client = ollama.Client()
        target_model = 'smart-qwen'
        try:
            client.show(target_model)
        except Exception:
            target_model = 'qwen3.8:27b'
            try:
                client.show(target_model)
            except Exception:
                target_model = 'qwen2.5-32b-uncensored'
                try:
                    client.show(target_model)
                except Exception:
                    target_model = 'qwen2.5-uncensored'

        response = client.chat(
            model=target_model,
            messages=[
                {'role': 'system', 'content': system_prompt},
                {'role': 'user', 'content': user_prompt}
            ],
            options={'temperature': 0.4},
            keep_alive=0
        )
        print("[0;32m🤖 [로컬 AI 실시간 시스템 종합 진단 리포트]:[0m
")
        print(response['message']['content'])
    except Exception as e:
        print(f"[0;31m❌ Ollama 진단 실행 오류: {e}[0m")
        print("💡 팁: 'sudo systemctl restart ollama.service' 로 Ollama 서비스가 켜져 있는지 확인하세요.")

if __name__ == '__main__':
    main()
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
