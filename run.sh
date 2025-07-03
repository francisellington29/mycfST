#!/bin/bash
# CloudflareSpeedTest DDNS v2.0 - 终端运行脚本

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 检查scripts目录是否存在
if [[ ! -d "$SCRIPT_DIR/scripts" ]]; then
    echo "错误: scripts目录不存在"
    echo "请确保在项目根目录下运行此脚本"
    exit 1
fi

# 检查entrypoint.sh是否存在
if [[ ! -f "$SCRIPT_DIR/entrypoint.sh" ]]; then
    echo "错误: entrypoint.sh不存在"
    exit 1
fi

# 设置执行权限
chmod +x "$SCRIPT_DIR"/*.sh "$SCRIPT_DIR/scripts"/*.sh

# 执行entrypoint.sh
exec "$SCRIPT_DIR/entrypoint.sh" "$@"