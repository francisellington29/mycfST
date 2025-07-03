#!/bin/bash
# CloudflareSpeedTest DDNS v2.0 - 常量和全局变量定义

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# 日志级别
readonly LOG_DEBUG=0
readonly LOG_INFO=1
readonly LOG_WARN=2
readonly LOG_ERROR=3

# 全局目录变量
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPTS_DIR")"
RESULT_FILE="$PROJECT_DIR/CloudflareST/result.csv"

# 日志目录统一使用项目根目录下的logs
LOG_DIR="$PROJECT_DIR/logs"

# 当前日志级别
CURRENT_LOG_LEVEL=${LOG_INFO}

# GitHub下载配置（从环境变量或配置文件读取）
# GITHUB_PROXY 在配置文件中设置
readonly INIT_FLAG_FILE=".initialized"
readonly CLOUDFLARE_ST_PATH="./CloudflareST/CloudflareST"
readonly CLOUDFLARE_ST_VERSION="v2.3.0"