# 构建指南

本文档说明如何使用统一构建脚本构建 Claude Proxy 项目。

## 🚀 快速开始

### 最简单的方式：一键构建

```bash
# 构建当前平台（前端 + 后端）
./build.sh

# 构建产物将生成在 dist/ 目录
```

## 📋 详细用法

### 查看帮助

```bash
./build.sh --help
```

### 构建选项

#### 1️⃣ 构建当前平台（默认）

```bash
./build.sh
```

**输出:**
- `dist/claude-proxy-linux-amd64` (Linux)
- `dist/claude-proxy-darwin-arm64` (macOS Apple Silicon)
- `dist/claude-proxy-windows-amd64.exe` (Windows)

#### 2️⃣ 构建所有平台

```bash
./build.sh --all
```

**输出:**
- `dist/claude-proxy-linux-amd64`
- `dist/claude-proxy-linux-arm64`
- `dist/claude-proxy-darwin-amd64`
- `dist/claude-proxy-darwin-arm64`
- `dist/claude-proxy-windows-amd64.exe`

#### 3️⃣ 构建特定平台

```bash
./build.sh -p linux-amd64      # Linux x86_64
./build.sh -p linux-arm64      # Linux ARM64
./build.sh -p darwin-amd64     # macOS Intel
./build.sh -p darwin-arm64     # macOS Apple Silicon
./build.sh -p windows-amd64    # Windows x86_64
```

#### 4️⃣ 仅构建前端

```bash
./build.sh --frontend-only
```

**输出:**
- `frontend/dist/` - 前端静态资源

#### 5️⃣ 跳过前端构建

如果前端已经构建过，可以跳过前端构建步骤：

```bash
./build.sh --skip-frontend
```

#### 6️⃣ 清理构建产物

```bash
./build.sh --clean
```

清理以下目录：
- `dist/`
- `frontend/dist/`
- `backend-go/frontend/dist/`

## 🛠️ 使用 Makefile（替代方式）

项目根目录的 Makefile 提供了便捷的快捷命令：

```bash
# 构建当前平台
make build

# 构建所有平台
make build-all

# 构建特定平台
make build-linux      # Linux (amd64 + arm64)
make build-darwin     # macOS (amd64 + arm64)
make build-windows    # Windows (amd64)

# 仅构建前端
make build-frontend

# 清理
make clean

# 查看所有命令
make help
```

## 🔧 构建流程

统一构建脚本自动完成以下步骤：

```
1. 构建前端 (Vue 3 + Vuetify)
   └─> 使用 Bun 或 npm
   └─> 输出到 frontend/dist/

2. 复制前端资源
   └─> 复制到 backend-go/frontend/dist/
   └─> Go 通过 embed.FS 嵌入资源

3. 构建 Go 后端
   └─> 注入版本信息 (从 VERSION 文件)
   └─> 交叉编译到目标平台
   └─> 输出到 dist/

4. 生成可执行文件
   └─> 单个二进制文件（包含前端资源）
   └─> 可直接部署运行
```

## 📦 版本信息注入

构建脚本会自动注入以下版本信息：

- **版本号**: 从 `VERSION` 文件读取
- **构建时间**: UTC 时间戳
- **Git 提交**: 当前 Git commit hash

查看版本信息：

```bash
./dist/claude-proxy-linux-amd64 --version
# 或在运行时访问健康检查端点
curl http://localhost:3000/health
```

## 🎯 开发 vs 生产

### 开发模式

开发时使用热重载：

```bash
# 使用 Makefile
make dev

# 或直接在后端目录
cd backend-go && make dev
```

### 生产构建

生产部署时使用构建脚本：

```bash
# 1. 构建
./build.sh --all

# 2. 部署对应平台的二进制文件
# 例如：将 dist/claude-proxy-linux-amd64 部署到 Linux 服务器
```

## 🐳 Docker 构建

Docker 镜像构建会自动调用构建脚本：

```bash
# 构建 Docker 镜像
docker build -t claude-proxy:latest .

# 或使用 docker-compose
docker-compose build
```

## 📝 注意事项

1. **前端构建工具**: 优先使用 Bun，如果未安装则使用 npm
2. **Go 版本**: 需要 Go 1.22 或更高版本
3. **构建产物**: 所有二进制文件都包含嵌入的前端资源，无需额外部署文件
4. **交叉编译**: 可以在任意平台构建其他平台的二进制文件

## 🔍 故障排除

### 前端构建失败

```bash
# 清理并重新安装依赖
cd frontend
rm -rf node_modules dist
npm install
npm run build
```

### Go 构建失败

```bash
# 更新 Go 依赖
cd backend-go
go mod tidy
go mod download
```

### 清理所有构建产物

```bash
./build.sh --clean
```

## 📚 相关文档

- [README.md](README.md) - 快速入门和部署指南
- [DEVELOPMENT.md](DEVELOPMENT.md) - 开发流程和调试技巧
- [ARCHITECTURE.md](ARCHITECTURE.md) - 技术架构设计
- [CONTRIBUTING.md](CONTRIBUTING.md) - 贡献规范

---

💡 **提示**: 推荐使用统一构建脚本 (`./build.sh`)，它比单独运行前后端构建命令更方便、更可靠。
