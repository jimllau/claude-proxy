#!/bin/bash

# Claude Proxy 统一构建脚本
# 用途：一键构建前端和后端，生成最终的 Go 可执行程序

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 构建配置
VERSION=$(cat VERSION 2>/dev/null || echo "v0.0.0-dev")
BUILD_TIME=$(date -u '+%Y-%m-%d_%H:%M:%S_UTC')
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
LDFLAGS="-s -w -X main.Version=${VERSION} -X main.BuildTime=${BUILD_TIME} -X main.GitCommit=${GIT_COMMIT}"

# 输出目录
OUTPUT_DIR="dist"

# 帮助信息
show_help() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Claude Proxy 统一构建脚本${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "用法: ./build.sh [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help              显示此帮助信息"
    echo "  -p, --platform <name>   指定构建平台 (默认: 当前平台)"
    echo "  -a, --all               构建所有平台"
    echo "  --skip-frontend         跳过前端构建 (假设前端已构建)"
    echo "  --frontend-only         仅构建前端"
    echo "  --clean                 清理所有构建产物"
    echo ""
    echo "支持的平台:"
    echo "  - linux-amd64           Linux (x86_64)"
    echo "  - linux-arm64           Linux (ARM64)"
    echo "  - darwin-amd64          macOS (x86_64)"
    echo "  - darwin-arm64          macOS (ARM64/Apple Silicon)"
    echo "  - windows-amd64         Windows (x86_64)"
    echo ""
    echo "示例:"
    echo "  ./build.sh                         # 构建当前平台"
    echo "  ./build.sh --all                   # 构建所有平台"
    echo "  ./build.sh -p linux-amd64          # 仅构建 Linux AMD64"
    echo "  ./build.sh --skip-frontend         # 跳过前端构建"
    echo "  ./build.sh --clean                 # 清理构建产物"
    echo ""
}

# 清理函数
clean_all() {
    echo -e "${YELLOW}🧹 清理所有构建产物...${NC}"

    # 清理前端
    if [ -d "frontend/dist" ]; then
        rm -rf frontend/dist
        echo -e "${GREEN}  ✓ 已清理 frontend/dist${NC}"
    fi

    # 清理后端 Go 的前端副本
    if [ -d "backend-go/frontend/dist" ]; then
        rm -rf backend-go/frontend/dist
        echo -e "${GREEN}  ✓ 已清理 backend-go/frontend/dist${NC}"
    fi

    # 清理输出目录
    if [ -d "$OUTPUT_DIR" ]; then
        rm -rf "$OUTPUT_DIR"
        echo -e "${GREEN}  ✓ 已清理 $OUTPUT_DIR${NC}"
    fi

    # 清理后端 Go 的临时文件
    cd backend-go 2>/dev/null && make clean 2>/dev/null || true
    cd - >/dev/null 2>&1

    echo -e "${GREEN}✅ 清理完成！${NC}"
    exit 0
}

# 构建前端
build_frontend() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📦 步骤 1/3: 构建前端 (Vue 3 + Vuetify)${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

    cd frontend

    # 检查包管理器
    if command -v bun &> /dev/null; then
        echo -e "${GREEN}使用 Bun 构建...${NC}"
        bun install
        bun run build
    elif command -v npm &> /dev/null; then
        echo -e "${GREEN}使用 npm 构建...${NC}"
        npm install
        npm run build
    else
        echo -e "${RED}❌ 错误: 未找到 bun 或 npm${NC}"
        exit 1
    fi

    cd ..

    # 检查构建产物
    if [ ! -d "frontend/dist" ]; then
        echo -e "${RED}❌ 前端构建失败：未找到 frontend/dist 目录${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ 前端构建完成！${NC}"
    echo ""
}

# 复制前端资源到后端
copy_frontend_to_backend() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}📋 步骤 2/3: 复制前端资源到后端${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"

    # 创建后端前端目录
    rm -rf backend-go/frontend/dist
    mkdir -p backend-go/frontend/dist

    # 复制前端资源
    cp -r frontend/dist/* backend-go/frontend/dist/

    echo -e "${GREEN}✅ 前端资源复制完成！${NC}"
    echo ""
}

# 构建 Go 后端
build_go_backend() {
    local platform=$1

    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🔨 步骤 3/3: 构建 Go 后端${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📌 版本: ${VERSION}${NC}"
    echo -e "${YELLOW}🕐 构建时间: ${BUILD_TIME}${NC}"
    echo -e "${YELLOW}🔖 Git提交: ${GIT_COMMIT}${NC}"
    echo ""

    cd backend-go

    # 下载依赖
    echo -e "${GREEN}📥 下载 Go 依赖...${NC}"
    go mod download
    go mod tidy

    # 创建输出目录
    mkdir -p ../$OUTPUT_DIR

    if [ "$platform" = "all" ]; then
        build_all_platforms
    elif [ -n "$platform" ]; then
        build_specific_platform "$platform"
    else
        build_current_platform
    fi

    cd ..

    echo ""
    echo -e "${GREEN}✅ Go 后端构建完成！${NC}"
    echo ""
}

# 构建当前平台
build_current_platform() {
    echo -e "${GREEN}🔨 构建当前平台...${NC}"

    local os=$(go env GOOS)
    local arch=$(go env GOARCH)
    local output="../$OUTPUT_DIR/claude-proxy-${os}-${arch}"

    if [ "$os" = "windows" ]; then
        output="${output}.exe"
    fi

    echo -e "${BLUE}  → 目标: ${os}/${arch}${NC}"

    go build -ldflags "$LDFLAGS" -o "$output" .

    echo -e "${GREEN}  ✓ 构建成功: $output${NC}"
}

# 构建指定平台
build_specific_platform() {
    local platform=$1

    case $platform in
        linux-amd64)
            build_platform "linux" "amd64"
            ;;
        linux-arm64)
            build_platform "linux" "arm64"
            ;;
        darwin-amd64)
            build_platform "darwin" "amd64"
            ;;
        darwin-arm64)
            build_platform "darwin" "arm64"
            ;;
        windows-amd64)
            build_platform "windows" "amd64"
            ;;
        *)
            echo -e "${RED}❌ 不支持的平台: $platform${NC}"
            echo "支持的平台: linux-amd64, linux-arm64, darwin-amd64, darwin-arm64, windows-amd64"
            exit 1
            ;;
    esac
}

# 构建所有平台
build_all_platforms() {
    echo -e "${GREEN}🔨 构建所有平台...${NC}"
    echo ""

    build_platform "linux" "amd64"
    build_platform "linux" "arm64"
    build_platform "darwin" "amd64"
    build_platform "darwin" "arm64"
    build_platform "windows" "amd64"
}

# 构建特定平台的辅助函数
build_platform() {
    local os=$1
    local arch=$2
    local output="../$OUTPUT_DIR/claude-proxy-${os}-${arch}"

    if [ "$os" = "windows" ]; then
        output="${output}.exe"
    fi

    echo -e "${BLUE}  → 构建 ${os}/${arch}...${NC}"

    GOOS=$os GOARCH=$arch go build -ldflags "$LDFLAGS" -o "$output" .

    echo -e "${GREEN}  ✓ 已完成: $output${NC}"
}

# 显示构建结果
show_build_results() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🎉 构建完成！${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}📁 构建产物位于 $OUTPUT_DIR/ 目录：${NC}"
    echo ""

    if [ -d "$OUTPUT_DIR" ]; then
        ls -lh $OUTPUT_DIR/ | grep -v "^total" | awk '{
            size=$5
            file=$9
            if (file != "") {
                # 颜色化输出
                printf "  \033[0;36m%-35s\033[0m %s\n", file, size
            }
        }'
    fi

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}💡 使用方法：${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} 复制对应平台的二进制文件到目标机器"
    echo -e "  ${GREEN}2.${NC} 创建 .env 文件配置环境变量（参考 ENVIRONMENT.md）"
    echo -e "  ${GREEN}3.${NC} 运行程序："
    echo ""

    if [ -f "$OUTPUT_DIR/claude-proxy-linux-amd64" ]; then
        echo -e "     ${BLUE}Linux:${NC}   ./$OUTPUT_DIR/claude-proxy-linux-amd64"
    fi
    if [ -f "$OUTPUT_DIR/claude-proxy-darwin-arm64" ]; then
        echo -e "     ${BLUE}macOS:${NC}   ./$OUTPUT_DIR/claude-proxy-darwin-arm64"
    fi
    if [ -f "$OUTPUT_DIR/claude-proxy-windows-amd64.exe" ]; then
        echo -e "     ${BLUE}Windows:${NC} .$OUTPUT_DIR\\claude-proxy-windows-amd64.exe"
    fi

    echo ""
    echo -e "${YELLOW}📌 版本信息：${NC}"
    echo -e "     版本: ${VERSION}"
    echo -e "     构建时间: ${BUILD_TIME}"
    echo -e "     Git提交: ${GIT_COMMIT}"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

# ============================================================================
# 主程序
# ============================================================================

# 解析命令行参数
SKIP_FRONTEND=false
FRONTEND_ONLY=false
BUILD_PLATFORM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -a|--all)
            BUILD_PLATFORM="all"
            shift
            ;;
        -p|--platform)
            BUILD_PLATFORM="$2"
            shift 2
            ;;
        --skip-frontend)
            SKIP_FRONTEND=true
            shift
            ;;
        --frontend-only)
            FRONTEND_ONLY=true
            shift
            ;;
        --clean)
            clean_all
            ;;
        *)
            echo -e "${RED}❌ 未知选项: $1${NC}"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# 显示构建信息
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}  ${GREEN}Claude Proxy 统一构建脚本${NC}                            ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 仅构建前端
if [ "$FRONTEND_ONLY" = true ]; then
    build_frontend
    echo -e "${GREEN}✅ 前端构建完成！${NC}"
    exit 0
fi

# 构建流程
if [ "$SKIP_FRONTEND" = false ]; then
    build_frontend
    copy_frontend_to_backend
else
    echo -e "${YELLOW}⏭️  跳过前端构建${NC}"
    echo ""

    # 检查前端是否已构建
    if [ ! -d "frontend/dist" ]; then
        echo -e "${RED}❌ 错误：未找到前端构建产物 (frontend/dist)${NC}"
        echo -e "${YELLOW}提示：请先构建前端，或移除 --skip-frontend 选项${NC}"
        exit 1
    fi

    copy_frontend_to_backend
fi

build_go_backend "$BUILD_PLATFORM"

# 显示构建结果
show_build_results
