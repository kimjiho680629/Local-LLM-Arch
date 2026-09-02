#!/usr/bin/env bash

# ==============================================================================
# 🚀 Local-LLM-Arch 스마트 GitHub 업데이트 & 변경 내역(Changelog) 자동 기록기
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO_DIR="/home/kjh/Projects/Local-LLM-Arch"
cd "$REPO_DIR"

echo -e "${CYAN}================================================================${NC}"
echo -e "${GREEN}  🚀 Local-LLM-Arch GitHub 업데이트 & 변경 이력 자동 기록기  ${NC}"
echo -e "${CYAN}================================================================${NC}\n"

# 1. 변경된 파일 상태 확인 및 표시
MODIFIED_FILES=$(git status --porcelain)
if [ -n "$MODIFIED_FILES" ]; then
    echo -e "${BLUE}📁 [감지된 변경 파일 목록]:${NC}"
    git status --short
    echo ""
else
    echo -e "${YELLOW}ℹ️  현재 수정된 파일이 없으나, 새로운 업데이트 내역을 기록하여 푸시할 수 있습니다.${NC}\n"
fi

# 2. 업데이트 내용 입력받기
TITLE=""
DETAILS=""

if [ $# -gt 0 ]; then
    TITLE="$*"
else
    echo -e "${YELLOW}✏️  이번 업데이트의 [핵심 제목/한 줄 요약]을 입력하세요:${NC}"
    echo -e "${CYAN}   (예: Qwen 3.8 27B 모델 파라미터 최적화 및 가이드 갱신)${NC}"
    read -r -p "  제목 > " TITLE
    
    if [ -z "$TITLE" ]; then
        TITLE="로컬 LLM 가이드 문서 및 스크립트 기능 최적화"
    fi

    echo -e "\n${YELLOW}📝 [상세 변경 내용]을 입력하세요 (엔터 시 완료, 없으면 그냥 엔터):${NC}"
    echo -e "${CYAN}   (예: - 컨텍스트 윈도우 16K 안정성 보강)${NC}"
    read -r -p "  상세 > " DETAILS
fi

CURRENT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

# 3. CHANGELOG.md 자동 업데이트 (파이썬으로 마크다운 안전 포맷팅)
CHANGELOG_FILE="$REPO_DIR/CHANGELOG.md"
if [ -f "$CHANGELOG_FILE" ]; then
    echo -e "\n${YELLOW}[1/4] CHANGELOG.md에 변경 이력 자동 기록 중...${NC}"
    
    python3 -c "
import sys

title = sys.argv[1]
details = sys.argv[2]
date_str = sys.argv[3]
changelog_path = sys.argv[4]

new_entry = f'## 📌 [{date_str}] - {title}\n'
if details.strip():
    new_entry += '### 🌟 변경 내용\n'
    for line in details.strip().split('\n'):
        line = line.strip()
        if line:
            new_entry += (line if line.startswith(('-', '*')) else f'* {line}') + '\n'
else:
    new_entry += f'* {title}\n'

new_entry += '\n---\n\n'

try:
    with open(changelog_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 첫 번째 구분선(---) 아래에 새 이력 삽입
    if '---' in content:
        parts = content.split('---', 1)
        updated = parts[0] + '---\n\n' + new_entry + parts[1].lstrip('\n')
    else:
        updated = content + '\n\n' + new_entry

    with open(changelog_path, 'w', encoding='utf-8') as f:
        f.write(updated)
    print('  ✓ CHANGELOG.md 갱신 완료')
except Exception as e:
    print(f'  ⚠️ CHANGELOG 갱신 실패: {e}')
" "$TITLE" "$DETAILS" "$CURRENT_DATE" "$CHANGELOG_FILE"
fi

# 4. Git 스테이징 및 커밋
echo -e "\n${YELLOW}[2/4] 변경 사항 스테이징 중 (git add)...${NC}"
git add .

echo -e "\n${YELLOW}[3/4] Git 커밋 생성 중...${NC}"
COMMIT_OUTPUT=""
if [ -n "$DETAILS" ]; then
    COMMIT_OUTPUT=$(git commit -m "$TITLE" -m "$DETAILS" 2>&1 || true)
else
    COMMIT_OUTPUT=$(git commit -m "$TITLE" 2>&1 || true)
fi

echo "$COMMIT_OUTPUT" | grep -E "\[main|files changed|file changed|insertions|deletions" || echo "  • 커밋 완료"

# 5. GitHub 원격 저장소 푸시
echo -e "\n${YELLOW}[4/4] GitHub 원격 저장소로 푸시 중 (git push)...${NC}"
if git push origin main; then
    echo -e "\n${GREEN}================================================================${NC}"
    echo -e "${GREEN}  🎉 GitHub에 변경 사항 및 업데이트 내용이 성공적으로 반영되었습니다!  ${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "  • ${CYAN}커밋 제목${NC}: $TITLE"
    [ -n "$DETAILS" ] && echo -e "  • ${CYAN}상세 내용${NC}: $DETAILS"
    echo -e "  • ${CYAN}반영 일시${NC}: $CURRENT_DATE"
    echo -e "  • ${CYAN}저장소 URL${NC}: https://github.com/kimjiho680629/Local-LLM-Arch\n"
else
    echo -e "\n${RED}⚠️ GitHub 푸시 중 오류가 발생했습니다.${NC}"
    echo -e "💡 터미널에서 'git push origin main'을 실행하여 세부 에러를 확인하세요."
fi
