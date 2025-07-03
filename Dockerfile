FROM alpine:3.20

# 设置维护者信息
LABEL maintainer="CloudflareSpeedTest DDNS v2.0"
LABEL description="Modern DDNS automation tool based on CloudflareSpeedTest v2.3.0"

# 安装依赖包
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    dcron \
    tzdata \
    ca-certificates \
    wget \
    tar \
    bc

# 设置工作目录
WORKDIR /app

# CloudflareSpeedTest将在运行时自动下载

# 复制入口脚本和配置
COPY entrypoint.sh run.sh ./
COPY scripts/ ./scripts/
COPY config.conf ./
RUN chmod +x *.sh scripts/*.sh

# 创建日志目录
RUN mkdir -p logs

# 设置时区
ENV TZ=Asia/Shanghai

# 健康检查
HEALTHCHECK --interval=5m --timeout=10s --retries=3 \
    CMD pgrep crond > /dev/null || exit 1

# 启动容器
CMD ["./entrypoint.sh"]