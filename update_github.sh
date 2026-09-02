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

# 1. 변경된 파일 상태 점검
MODIFIED_FILES=$(git status --porcelain)
if [ -z "$MODIFIED_FILES" ]; then
    echo -e "${YELLOW}⚠️ 변경된 파일이 없습니다. 저장소가 최신 상태입니다.${NC}"
    exit 0
fi

echo -e "${BLUE}📁 [감지된 변경 파일 목록]:${NC}"
git status --short
echo ""

# 2. 업데이트 내용 입력받기
TITLE=""
DETAILS=""

if [ $# -gt 0 ]; then
    TITLE="$*"
else
    echo -e "${YELLOW}✏️  이번 업데이트의 [핵심 제목/한 줄 요약]을 입력하세요:${NC}"
    read -r -p "  제목 > " TITLE
    
    if [ -z "$TITLE" ]; then
        TITLE="문서 및 스크립트 기능 개선"
    fi

    echo -e "\n${YELLOW}📝 [상세 변경 내용]을 입력하세요 (예: - Qwen 모델 파라미터 튜닝 / 엔터 시 완료):${NC}"
    echo -e "${CYAN}   (여러 줄 입력 가능, 완료 시 빈 줄에서 엔터)${NC}"
    
    DETAIL_LINES=()
    while IFS= read -r line; do
        [ -z "$line" ] && break
        DETAIL_LINES+=("$line")
    done
    
    if [ ${#DETAIL_LINES[@]} -gt 0 ]; then
        DETAILS=$(printf "%s\n" "${DETAIL_LINES[@]}")
    fi
fi

CURRENT_DATE=$(date '+%Y-%m-%d')
CURRENT_TIME=$(date '+%H:%M:%S')

# 3. CHANGELOG.md 자동 업데이트
CHANGELOG_FILE="$REPO_DIR/CHANGELOG.md"
if [ -f "$CHANGELOG_FILE" ]; then
    echo -e "\n${YELLOW}[1/4] CHANGELOG.md에 변경 이력 자동 기록 중...${NC}"
    
    NEW_ENTRY="## 📌 [${CURRENT_DATE} ${CURRENT_TIME}] - ${TITLE}\n"
    if [ -n "$DETAILS" ]; then
        NEW_ENTRY+="### 🌟 변경 내용\n"
        while IFS= read -r d_line; do
            [[ "$d_line" =~ ^[*-] ]] && NEW_ENTRY+="$d_line\n" || NEW_ENTRY+="* $d_line\n"
        done <<< "$DETAILS"
    else
        NEW_ENTRY+="* $TITLE\n"
    fi
    NEW_ENTRY+="\n---\n"

    # CHANGELOG.md 헤더 아래에 새 항목 삽입
    TEMP_FILE=$(mktemp)
    awk -v entry="$NEW_ENTRY" '
        BEGIN { inserted = 0 }
        /^---$/ && !inserted {
            print $0
            print ""
            printf "%s", entry
            inserted = 1
            next
        }
        { print }
    ' "$CHANGELOG_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$CHANGELOG_FILE"
    echo -e "  ${GREEN}✓ CHANGELOG.md 갱신 완료${NC}"
fi

# 4. Git 스테이징 및 커밋
echo -e "\n${YELLOW}[2/4] 변경 사항 스테이징 중 (git add)...${NC}"
git add .

echo -e "\n${YELLOW}[3/4] Git 커밋 생성 중...${NC}"
if [ -n "$DETAILS" ]; then
    git commit -m "$TITLE" -m "$DETAILS"
else
    git commit -m "$TITLE"
fi

# 5. GitHub 원격 저장소 푸시
echo -e "\n${YELLOW}[4/4] GitHub 원격 저장소로 푸시 중 (git push)...${NC}"
if git push -u origin main; then
    echo -e "\n${GREEN}================================================================${NC}"
    echo -e "${GREEN}  🎉 GitHub에 변경 사항 및 업데이트 내용이 성공적으로 반영되었습니다!  ${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo -e "  • ${CYAN}커밋 제목${NC}: $TITLE"
    echo -e "  • ${CYAN}반영 일시${NC}: $CURRENT_DATE $CURRENT_TIME"
    echo -e "  • ${CYAN}저장소 URL${NC}: $(git remote get-url origin 2>/dev/null || echo 'https://github.com/kimjiho680629/Local-LLM-Arch')\n"
else
    echo -e "\n${RED}⚠️ GitHub 푸시 중 인증 또는 네트워크 오류가 발생했습니다.${NC}"
    echo -e "💡 저장소가 생성되어 있는지, 또는 토큰/로그인 권한을 확인해 주세요."
fi
