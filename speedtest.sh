#!/bin/bash

# CloudflareSpeedTest 测速脚本
# 专门负责参数拼接和执行测速

set -e

# 加载常量定义
source /app/constants.sh

log_message "INFO" "CloudflareSpeedTest 测速开始"

# 切换到CloudflareST工作目录
cd "$CLOUDFLARE_ST_DIR"

# 所有参数直接从环境变量获取，在构建命令时处理默认值

# 构建 CloudflareST 命令参数
build_speedtest_args() {
    local args=""

    # 基本参数
    if [ -n "$SPEEDTEST_THREADS" ]; then
        args="$args -n $SPEEDTEST_THREADS"
    fi

    if [ -n "$SPEEDTEST_LATENCY_TIMES" ]; then
        args="$args -t $SPEEDTEST_LATENCY_TIMES"
    fi

    if [ -n "$SPEEDTEST_DOWNLOAD_NUM" ]; then
        args="$args -dn $SPEEDTEST_DOWNLOAD_NUM"
    fi

    if [ -n "$SPEEDTEST_DOWNLOAD_TIME" ]; then
        args="$args -dt $SPEEDTEST_DOWNLOAD_TIME"
    fi

    if [ -n "$SPEEDTEST_PORT" ]; then
        args="$args -tp $SPEEDTEST_PORT"
    fi

    # 测速地址
    if [ -n "$SPEEDTEST_URL" ]; then
        args="$args -url $SPEEDTEST_URL"
    fi

    # 测速模式
    if [ "$SPEEDTEST_HTTPING" = "true" ]; then
        args="$args -httping"
        if [ -n "$SPEEDTEST_HTTP_CODE" ]; then
            args="$args -httping-code $SPEEDTEST_HTTP_CODE"
        fi
    fi

    # 地区匹配
    if [ -n "$SPEEDTEST_COLO" ]; then
        args="$args -cfcolo $SPEEDTEST_COLO"
    fi

    # 过滤条件
    if [ -n "$SPEEDTEST_LATENCY_MAX" ]; then
        args="$args -tl $SPEEDTEST_LATENCY_MAX"
    fi

    if [ -n "$SPEEDTEST_LATENCY_MIN" ]; then
        args="$args -tll $SPEEDTEST_LATENCY_MIN"
    fi

    if [ -n "$SPEEDTEST_LOSS_RATE" ]; then
        args="$args -tlr $SPEEDTEST_LOSS_RATE"
    fi

    if [ -n "$SPEEDTEST_SPEED_MIN" ]; then
        args="$args -sl $SPEEDTEST_SPEED_MIN"
    fi

    # 输出控制
    if [ -n "$SPEEDTEST_RESULT_NUM" ]; then
        args="$args -p $SPEEDTEST_RESULT_NUM"
    fi

    # IP数据源
    if [ -n "$SPEEDTEST_IP_RANGE" ]; then
        args="$args -ip $SPEEDTEST_IP_RANGE"
    elif [ -n "$SPEEDTEST_IP_FILE" ] && [ -f "$SPEEDTEST_IP_FILE" ]; then
        args="$args -f $SPEEDTEST_IP_FILE"
    elif [ -f "$IPV4_DATA_FILE" ]; then
        args="$args -f $IPV4_DATA_FILE"
    fi

    # 输出文件
    args="$args -o $RESULT_FILE"

    # 其他选项
    if [ "$SPEEDTEST_DISABLE_DOWNLOAD" = "true" ]; then
        args="$args -dd"
    fi

    if [ "$SPEEDTEST_ALL_IP" = "true" ]; then
        args="$args -allip"
    fi

    if [ "$SPEEDTEST_DEBUG" = "true" ]; then
        args="$args -debug"
    fi

    echo "$args"
}

# 显示测试参数
log_message "INFO" "测试参数配置:"
if [ -n "$SPEEDTEST_THREADS" ]; then
    log_message "INFO" "  延迟测速线程数: $SPEEDTEST_THREADS"
fi
if [ -n "$SPEEDTEST_LATENCY_TIMES" ]; then
    log_message "INFO" "  延迟测速次数: $SPEEDTEST_LATENCY_TIMES"
fi
if [ -n "$SPEEDTEST_DOWNLOAD_NUM" ]; then
    log_message "INFO" "  下载测速数量: $SPEEDTEST_DOWNLOAD_NUM"
fi
if [ -n "$SPEEDTEST_DOWNLOAD_TIME" ]; then
    log_message "INFO" "  下载测速时间: ${SPEEDTEST_DOWNLOAD_TIME}s"
fi
if [ -n "$SPEEDTEST_PORT" ]; then
    log_message "INFO" "  测速端口: $SPEEDTEST_PORT"
fi
if [ -n "$SPEEDTEST_HTTPING" ]; then
    log_message "INFO" "  HTTP模式: $SPEEDTEST_HTTPING"
fi
log_message "INFO" "  结果文件: $RESULT_FILE"

# 构建命令参数
SPEEDTEST_ARGS=$(build_speedtest_args)
log_message "INFO" "CloudflareST 参数: $SPEEDTEST_ARGS"

# 执行CloudflareSpeedTest
log_message "INFO" "开始执行速度测试..."
log_message "INFO" "命令: ./CloudflareST $SPEEDTEST_ARGS"

# 执行测速命令
eval "./CloudflareST $SPEEDTEST_ARGS"
SPEEDTEST_EXIT_CODE=$?

# 检查执行结果
if [[ $SPEEDTEST_EXIT_CODE -eq $EXIT_SUCCESS ]] && validate_file "$RESULT_FILE"; then
    log_message "INFO" "测速执行成功"

    # 显示结果文件信息
    if [[ -s "$RESULT_FILE" ]]; then
        line_count=$(wc -l < "$RESULT_FILE")
        log_message "INFO" "结果文件已生成: $RESULT_FILE"
        log_message "INFO" "文件大小: $line_count 行"

        # 显示前几行结果作为预览
        log_message "INFO" "=== 测速结果预览 ==="
        head -n 6 "$RESULT_FILE" | while IFS= read -r line; do
            log_message "INFO" "$line"
        done
        log_message "INFO" "===================="
    else
        log_message "WARN" "结果文件为空"
    fi
else
    log_message "ERROR" "测速执行失败，退出码: $SPEEDTEST_EXIT_CODE"
fi

log_message "INFO" "CloudflareSpeedTest 测速完成"

# 返回执行结果
exit $SPEEDTEST_EXIT_CODE
