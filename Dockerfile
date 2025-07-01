# 使用 Alpine Linux 作为基础镜像
FROM alpine:3.20

# 设置工作目录
WORKDIR /app

# 安装必要的系统依赖
RUN apk add --no-cache \
    bash \
    jq \
    wget \
    curl \
    ca-certificates \
    dcron \
    && rm -rf /var/cache/apk/*

# 复制核心文件到容器
COPY entrypoint.sh .
COPY start.sh .
COPY config.conf .
COPY cf_ddns/ ./cf_ddns/

# 确保脚本有执行权限
RUN chmod +x entrypoint.sh && \
    chmod +x start.sh && \
    chmod +x cf_ddns/*.sh

# 设置环境变量
ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8

# 健康检查（检查cron服务和配置文件）
HEALTHCHECK --interval=5m --timeout=10s --start-period=30s --retries=3 \
    CMD sh -c "pgrep crond && test -f /app/config.conf" || exit 1


CMD ["bash", "entrypoint.sh"]
