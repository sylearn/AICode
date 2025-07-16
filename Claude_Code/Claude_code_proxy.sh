#!/bin/bash
# ==================================================
# Claude Code + Claude Code Proxy 环境自动化部署脚本
# ==================================================
# 
# 功能说明：
# 1. 自动检测并安装必要的依赖工具（uv、npm）
# 2. 检测并安装 Claude Code
# 3. 管理 Claude Code Proxy 的安装、启动和端口冲突处理
# 4. 配置代理环境并启动 Claude Code
# 
# 执行流程：
# ├── 环境检查
# │   ├── 检查 uv 是否安装（Python 包管理器）
# │   ├── 检查 Claude Code 是否安装
# │   └── 检查 npm/Node.js 环境
# ├── Claude Code Proxy 管理
# │   ├── 检查是否已安装
# │   ├── 检查端口占用情况（默认8082）
# │   ├── 清理冲突进程
# │   └── 启动代理服务
# └── 启动 Claude Code
#     ├── 配置代理环境变量
#     └── 启动 Claude Code 客户端
# 
# 注意事项：
# - 确保网络连接正常，用于下载依赖
# - 脚本会自动处理端口冲突
# - 配置参数可在下方"设置区域"进行修改
# ==================================================
# === 设置区域：可根据需要修改 ===
# control command and directory
CLAUDE_COMMAND="claude"   # or claude, if you install another version
CLAUDE_DIR="$HOME/.claude" # your Claude Code config directory
CLAUDE_PROXY_DIR="$HOME/.claude/proxy" # your Claude Code Proxy config directory
PROXY_PROJECT_DIR="$CLAUDE_PROXY_DIR/claude-code-proxy" # your Claude Code Proxy project directory
CURRENT_DIR=$(cd $(dirname $0); pwd) # current path

PROXY_PORT=8082 # proxy port
OPENAI_API_KEY=sk-** # your openai api key
OPENAI_BASE_URL=https://api.yourdomain.com/v1 # your openai base url
BIG_MODEL="gemini-2.5-pro-preview-06-05" # big model
SMALL_MODEL="gpt-4o-mini" # small model

ANTHROPIC_AUTH_TOKEN="api-key" # proxy token, don't change
LOG_LEVEL="WARNING" # log level
MAX_TOKENS_LIMIT=65535 #65535 for gemini-2.5-pro-preview-06-05; 4096 for gpt-4o/claude
MIN_TOKENS_LIMIT=4096 # min tokens limit
REQUEST_TIMEOUT=90 # request timeout
MAX_RETRIES=3 # max retries

# proxy parameters
HOST="0.0.0.0" # service listen address
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS，默认使用 en0 网卡
    ip=$(ipconfig getifaddr en0 2>/dev/null)
    # 如果获取失败或为空，使用localhost
    if [[ -z "$ip" ]]; then
        ip="localhost"
    fi
else
    # Linux
    ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    # 如果获取失败或为空，使用localhost
    if [[ -z "$ip" ]]; then
        ip="localhost"
    fi
fi

ANTHROPIC_BASE_URL=http://$ip:$PROXY_PORT # proxy address


#==================================================
# 函数定义
#==================================================
# 创建全新的.env文件，包含所有必需的配置
create_env_file() {
  local env_file="$PROXY_PROJECT_DIR/.env"

  echo "🔧 正在创建全新的.env配置文件..."

  # 删除现有的.env文件（如果存在）
  if [ -f "$env_file" ]; then
    rm "$env_file"
    echo "已删除现有的.env文件: $env_file"
  fi

  # 创建新的.env文件，包含所有配置
  cat > "$env_file" << EOF
HOST="$HOST"
PROXY_PORT="$PROXY_PORT"
OPENAI_API_KEY="$OPENAI_API_KEY"
OPENAI_BASE_URL="$OPENAI_BASE_URL"
BIG_MODEL="$BIG_MODEL"
SMALL_MODEL="$SMALL_MODEL"
LOG_LEVEL="$LOG_LEVEL"
MAX_TOKENS_LIMIT="$MAX_TOKENS_LIMIT"
MIN_TOKENS_LIMIT="$MIN_TOKENS_LIMIT"
REQUEST_TIMEOUT="$REQUEST_TIMEOUT"
MAX_RETRIES="$MAX_RETRIES"
EOF

  echo "✅ 已创建新的.env文件: $env_file"
  echo "配置完成 - 大模型: $BIG_MODEL, 最大令牌: $MAX_TOKENS_LIMIT"
}


echo "📦 正在检查 Claude Code 是否已安装..."
# 判断命令是否存在
if command -v $CLAUDE_COMMAND &>/dev/null; then
    echo "✅ $CLAUDE_COMMAND 已安装"
else
    echo "❌ 未检测到 $CLAUDE_COMMAND，尝试使用 npm 全局安装..."

    if ! command -v npm &>/dev/null; then
        echo "❌ 未检测到 npm，请先安装 Node.js"
        exit 1
    fi

    echo "📥 正在安装 Claude Code..."
    if npm install -g @anthropic-ai/claude-code; then
        echo "✅ Claude Code 安装完成"
    else
        echo "❌ 安装失败，请检查网络或权限"
        exit 1
    fi
fi

# 检查uv是否安装
echo "📦 正在检查 uv 是否已安装..."

if command -v uv &>/dev/null; then
    echo "✅ uv 已安装"
else
    echo "❌ 未检测到 uv，正在尝试安装..."
    
    # 检查是否有curl
    if command -v curl &>/dev/null; then
        echo "📥 正在使用 curl 安装 uv..."
        if curl -LsSf https://astral.sh/uv/install.sh | sh; then
            echo "✅ uv 安装完成"
            # 重新加载环境变量
            export PATH="$HOME/.cargo/bin:$PATH"
        else
            echo "❌ uv 安装失败，请检查网络连接"
            exit 1
        fi
    else
        echo "❌ 未检测到 curl，无法自动安装 uv"
        echo "请手动安装 uv: https://docs.astral.sh/uv/getting-started/installation/"
        exit 1
    fi
fi


# 检查 Claude Code Proxy是否安装
# git clone https://github.com/fuergaosi233/claude-code-proxy
if [ -d "$PROXY_PROJECT_DIR" ]; then
    echo "✅ Claude Code Proxy 已安装"

    # 创建全新的.env文件
    create_env_file

    echo "✅ Claude Code Proxy .env 配置完成"
    
    # 检查端口是否被占用
    echo "🔍 检查端口 $PROXY_PORT 是否被占用..."
    if lsof -ti:$PROXY_PORT > /dev/null 2>&1; then
        echo "⚠️ 端口 $PROXY_PORT 已被占用！"
        PID=$(lsof -ti:$PROXY_PORT)
        PROCESS_NAME=$(ps -p $PID -o comm= 2>/dev/null || echo "unknown")
        echo "   占用进程: PID $PID ($PROCESS_NAME)"
        
        read -p "是否要终止该进程以释放端口 $PROXY_PORT？(y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy是]$ ]]; then
            echo "正在终止进程 $PID..."
            if kill -9 $PID 2>/dev/null; then
                echo "✅ 进程 $PID 已终止，端口 $PROXY_PORT 已释放"
            else
                echo "❌ 无法终止进程 $PID，可能需要管理员权限"
                echo "请手动终止该进程或使用不同端口"
                exit 1
            fi
        else
            echo "❌ 用户选择不终止进程"
            echo "您可以："
            echo "1. 手动终止占用端口的进程"
            echo "2. 修改 PORT 环境变量使用其他端口"
            echo "3. 如果是之前的proxy进程，可以直接启动Claude Code"
            read -p "是否直接启动 Claude Code？(y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy是]$ ]]; then
                CLAUDE_CODE_MAX_OUTPUT_TOKENS=$MAX_TOKENS_LIMIT ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_AUTH_TOKEN claude
                exit 0
            else
                exit 1
            fi
        fi
    else
        echo "✅ 端口 $PROXY_PORT 可用"
    fi

    echo ""
    echo "========================================================"
    echo "           启动代理服务和 Claude Code"
    echo "========================================================"
    echo "    大模型: $BIG_MODEL"
    echo "    小模型: $SMALL_MODEL"
    echo "    代理地址: $ANTHROPIC_BASE_URL"
    echo "    最大令牌: $MAX_TOKENS_LIMIT"
    echo ""

    #运行claude-code-proxy
    uv run --directory $PROXY_PROJECT_DIR claude-code-proxy & sleep 1  && CLAUDE_CODE_MAX_OUTPUT_TOKENS=$MAX_TOKENS_LIMIT ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_AUTH_TOKEN claude
else
    echo "❌ 未检测到 Claude Code Proxy，是否安装？(y/n)"
    read -n 1 -p "请输入(y/n): " INSTALL_PROXY
    if [ "$INSTALL_PROXY" == "y" ]; then
        #在$CLAUDE_PROXY_DIR目录下执行git clone https://github.com/fuergaosi233/claude-code-proxy
        echo "📁 创建代理目录: $CLAUDE_PROXY_DIR"
        mkdir -p "$CLAUDE_PROXY_DIR"
        
        echo "📥 克隆 Claude Code Proxy 项目..."
        if cd "$CLAUDE_PROXY_DIR"; then
            git clone https://github.com/fuergaosi233/claude-code-proxy.git
            
            echo "🔧 进入项目目录并初始化..."
            if cd "$PROXY_PROJECT_DIR"; then
                uv sync

                # 回到原始目录以确保正确的执行上下文
                cd "$CURRENT_DIR"

                # 创建全新的.env文件
                create_env_file

                echo "✅ Claude Code Proxy 配置完成"
            else
                echo "❌ 无法进入项目目录: $PROXY_PROJECT_DIR"
                # 回到当前路径
                cd $CURRENT_DIR
                exit 1
            fi
        else
            echo "❌ 无法创建或进入代理目录: $CLAUDE_PROXY_DIR"
            # 回到当前路径
            cd $CURRENT_DIR
            exit 1
        fi
        # 回到当前路径
        cd $CURRENT_DIR
        # 检查端口是否被占用
        echo "🔍 检查端口 $PROXY_PORT 是否被占用..."
        if lsof -ti:$PROXY_PORT > /dev/null 2>&1; then
            echo "⚠️ 端口 $PROXY_PORT 已被占用！"
            PID=$(lsof -ti:$PROXY_PORT)
            PROCESS_NAME=$(ps -p $PID -o comm= 2>/dev/null || echo "unknown")
            echo "   占用进程: PID $PID ($PROCESS_NAME)"
            
            read -p "是否要终止该进程以释放端口 $PROXY_PORT？(y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy是]$ ]]; then
                echo "正在终止进程 $PID..."
                if kill -9 $PID 2>/dev/null; then
                    echo "✅ 进程 $PID 已终止，端口 $PROXY_PORT 已释放"
                else
                    echo "❌ 无法终止进程 $PID，可能需要管理员权限"
                    echo "请手动终止该进程或使用不同端口"
                    exit 1
                fi
            else
                echo "❌ 用户选择不终止进程，跳过安装"
                exit 1
            fi
        else
            echo "✅ 端口 $PROXY_PORT 可用"
        fi

        echo ""
        echo "========================================================"
        echo "           启动代理服务和 Claude Code"
        echo "========================================================"
        echo "    大模型: $BIG_MODEL"
        echo "    小模型: $SMALL_MODEL"
        echo "    代理地址: $ANTHROPIC_BASE_URL"
        echo "    最大令牌: $MAX_TOKENS_LIMIT"
        echo "    项目目录: $PROXY_PROJECT_DIR"
        echo "    当前目录: $(pwd)"
        echo ""

        # 验证项目设置
        if [ ! -d "$PROXY_PROJECT_DIR" ]; then
            echo "❌ 错误: 项目目录不存在: $PROXY_PROJECT_DIR"
            exit 1
        fi

        if [ ! -f "$PROXY_PROJECT_DIR/.env" ]; then
            echo "❌ 错误: .env文件不存在: $PROXY_PROJECT_DIR/.env"
            exit 1
        fi

        echo "✅ 项目设置验证通过"

        #运行claude-code-proxy
        uv run --directory $PROXY_PROJECT_DIR claude-code-proxy & sleep 1 && CLAUDE_CODE_MAX_OUTPUT_TOKENS=$MAX_TOKENS_LIMIT ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN=$ANTHROPIC_AUTH_TOKEN claude
    else
        echo "❌ 未安装 Claude Code Proxy"
    fi
fi