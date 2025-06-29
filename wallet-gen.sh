#!/usr/bin/env bash
set -euo pipefail

#—— 脚本和工作目录 ——#
SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
WORKDIR="$SCRIPT_DIR/gen"
PROJECT_DIR="$WORKDIR/wallet-gen"
PORT=8888
PIDFILE="$WORKDIR/wallet-gen.pid"

#—— 工具：检查命令并安装 ——#
check_command() {
  local cmd=$1 pkg=${2:-$1}
  if ! command -v "$cmd" &>/dev/null; then
    echo "⚠️ 未检测到 '$cmd'，正在安装……"
    apt-get update -y
    apt-get install -y "$pkg"
  fi
}

install_bun() {
  if ! command -v bun &>/dev/null; then
    echo "⚠️ 未检测到 bun，正在通过 bun.sh 安装……"
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
  else
    echo "✅ bun 已安装，版本：$(bun --version)"
  fi
}

#—— 功能：安装并启动网页钱包 ——#
start_web_wallet() {
  # 1) 安装依赖
  check_command curl
  check_command git
  install_bun

  # 2) 准备工作目录
  cd "$SCRIPT_DIR"
  mkdir -p "$WORKDIR"

  # 3) 克隆或刷新项目
  if [ -d "$PROJECT_DIR" ]; then
    echo "🔄 检测到旧版仓库，删除中……"
    rm -rf "$PROJECT_DIR"
  fi
  echo "🚀 克隆仓库 wallet-gen……"
  git clone https://github.com/octra-labs/wallet-gen.git "$PROJECT_DIR"

  # 4) 安装项目依赖
  cd "$PROJECT_DIR"
  echo "📦 执行 bun install……"
  bun install

  # 5) 后台启动 Bun 服务并记录 PID
  echo "🌐 启动 Bun 服务（端口 $PORT）……"
  # 用 setsid 分离进程组
  nohup setsid bun start > "$WORKDIR/wallet-gen.log" 2>&1 &
  echo $! > "$PIDFILE"

  # 6) 检测启动状态
  sleep 5
  if lsof -i :"$PORT" | grep LISTEN &>/dev/null; then
    read -rp "请输入 VPS 公网 IP: " VPS_IP
    read -rp "请输入 SSH 端口（默认 22）: " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}

    echo -e "\n✅ 服务启动成功！"
    echo "  本地端口转发命令："
    echo "    ssh -L $PORT:localhost:$PORT root@$VPS_IP -p $SSH_PORT"
    echo "  然后在浏览器访问：http://localhost:$PORT"
  else
    echo "❌ 服务启动失败，请查看日志：$WORKDIR/wallet-gen.log"
  fi

  read -rp $'\n按回车返回主菜单…' _
}

#—— 功能：删除并彻底停止服务 ——#
delete_gen() {
  # 切回脚本目录，避免在被删目录中卡死
  cd "$SCRIPT_DIR"

  echo "🛑 停止所有 bun 进程……"
  # 杀掉所有 bun 可执行程序
  if command -v pkill &>/dev/null; then
    pkill -9 -x bun && echo "  ✅ pkill 杀掉所有 bun 进程"
  else
    for pid in $(pgrep -f "bun start" || true); do
      kill -9 "$pid" && echo "  ✅ kill -9 PID=$pid"
    done
  fi

  echo "🛑 强制关闭监听端口 $PORT 的进程……"
  # 用 fuser 杀掉所有使用本端口的进程
  if command -v fuser &>/dev/null; then
    fuser -k ${PORT}/tcp && echo "  ✅ fuser -k 杀掉端口 $PORT 进程"
  else
    for pid in $(lsof -ti tcp:${PORT} || true); do
      kill -9 "$pid" && echo "  ✅ kill -9 PID=$pid (via lsof)"
    done
  fi

  # 再次验证端口是否关闭
  if lsof -ti tcp:${PORT} &>/dev/null; then
    echo "⚠️ 端口 $PORT 仍有进程，请手动排查：lsof -i:$PORT"
  else
    echo "✅ 端口 $PORT 已关闭"
  fi

  # 删除整个 gen 目录
  if [ -d "$WORKDIR" ]; then
    echo "🧹 删除目录：$WORKDIR"
    rm -rf "$WORKDIR"
    echo "✅ gen 目录及所有文件已删除！"
  else
    echo "⚠️ 未检测到 gen 目录：$WORKDIR"
  fi

  read -rp $'\n按回车返回主菜单…' _
}

#—— 菜单 ——#
show_menu() {
  clear
  echo "==== Octra Wallet 管理脚本 ===="
  echo "脚本位置：$SCRIPT_DIR"
  echo
  echo "1) 安装并启动网页钱包服务 (Bun)"
  echo "2) 删除钱包相关文件并停止服务"
  echo "3) 退出"
  echo
  read -rp "请选择操作 [1-3]: " CHOICE
}

#—— 主循环 ——#
while true; do
  show_menu
  case "$CHOICE" in
    1) start_web_wallet ;;
    2) delete_gen     ;;
    3) echo "退出，再见！"; exit 0 ;;
    *) echo "❌ 无效输入，请重新选择"; sleep 1 ;;
  esac
done

