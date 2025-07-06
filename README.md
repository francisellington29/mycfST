# CloudflareSpeedTest Docker 定时任务

这是一个基于Docker的CloudflareSpeedTest定时任务容器，可以自动定期测试Cloudflare CDN的延迟和速度，找到最优的IP地址，并自动更新DNS记录。

## 功能特性

- 🚀 自动定时执行Cloudflare速度测试
- 🌐 自动更新Cloudflare DNS记录到最优IP
- 📱 Telegram机器人通知测试结果和DNS更新状态
- 📊 支持自定义测试参数和调度时间
- 📁 结果自动保存到CSV文件（每次覆盖）
- 🌏 自动下载IP地理位置数据库(qqwry.dat)
- 📋 详细的日志记录
- 🔧 灵活的配置选项
- 🏗️支持多架构 (amd64, arm64, armv7, 386)
- 🔄 自动检测系统架构并下载对应版本
- 🧹 代码已优化，移除未使用的函数和文件

## 项目结构

```
CloudflareSpeedTestDDNS-simple/
├── constants.sh          # 全局常量和工具函数
├── start.sh             # 主控制脚本
├── dns_manager.sh       # DNS记录管理模块
├── notification.sh      # Telegram通知模块
├── speedtest.sh         # 网络测速模块
├── init.sh              # CloudflareST初始化脚本
├── entrypoint.sh        # Docker容器入口点
├── worker.js            # Cloudflare Worker代理服务
├── docker-compose.yml   # 容器编排配置
├── Dockerfile           # 镜像构建文件
└── rubbish/             # 已移除的废弃文件
```

## 快速开始

### 1. 克隆项目
```bash
git clone <your-repo-url>
cd CloudflareSpeedTestDDNS-simple
```

### 2. 配置环境变量
编辑 `docker-compose.yml` 文件，配置以下必要参数：

```yaml
environment:
  # Cloudflare DNS 配置
  - CLOUDFLARE_ZONE_ID=your_zone_id_here          # 你的Zone ID
  - CLOUDFLARE_API_TOKEN=your_api_token_here      # 你的API Token
  - CLOUDFLARE_DOMAIN=your_domain.com             # 要更新的域名

  # Telegram 机器人配置
  - TELEGRAM_BOT_TOKEN=your_bot_token_here         # 机器人Token
  - TELEGRAM_CHAT_ID=your_chat_id_here             # 聊天ID
  - TELEGRAM_PROXY_URL=your_proxy_url_here         # 代理URL(可选)
```

### 3. 启动容器
```bash
# 构建并启动容器
docker-compose up -d

# 查看日志
docker-compose logs -f
```

## 配置说明

### Cloudflare API 配置

1. **获取 Zone ID**：
   - 登录 Cloudflare 控制台
   - 选择你的域名
   - 在右侧边栏找到 "Zone ID"

2. **创建 API Token**：
   - 进入 "My Profile" > "API Tokens"
   - 点击 "Create Token"
   - 使用 "Custom token" 模板
   - 权限设置：`Zone:Zone:Read`, `Zone:DNS:Edit`
   - Zone Resources: `Include - Specific zone - your_domain.com`

### Telegram 机器人配置

1. **创建机器人**：
   - 与 @BotFather 对话
   - 发送 `/newbot` 创建新机器人
   - 获取 Bot Token

2. **获取 Chat ID**：
   - 与你的机器人对话
   - 访问 `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - 在返回的JSON中找到 `chat.id`

3. **代理设置（可选）**：
   - 如果需要代理访问Telegram，设置 `TELEGRAM_PROXY_URL`
   - 格式：`http://proxy_host:proxy_port` 或 `socks5://proxy_host:proxy_port`

## 环境变量配置

### 基本配置

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `CRON_SCHEDULE` | `0 */6 * * *` | 定时任务调度表达式 (每6小时) |
| `SPEEDTEST_THREADS` | `200` | 测试线程数 |
| `SPEEDTEST_TIMEOUT` | `10` | 超时时间(秒) |
| `TZ` | `Asia/Shanghai` | 时区设置 |

### Cloudflare DNS 配置

| 变量名 | 说明 | 必填 |
|--------|------|------|
| `CLOUDFLARE_ZONE_ID` | Cloudflare Zone ID | ✅ |
| `CLOUDFLARE_API_TOKEN` | Cloudflare API Token | ✅ |
| `CLOUDFLARE_DOMAIN` | 要更新的DNS记录名称 | ✅ |

### Telegram 机器人配置

| 变量名 | 说明 | 必填 |
|--------|------|------|
| `TELEGRAM_BOT_TOKEN` | Telegram 机器人 Token | ✅ |
| `TELEGRAM_CHAT_ID` | Telegram 聊天 ID | ✅ |
| `TELEGRAM_PROXY_URL` | 代理服务器URL | ❌ |

### CloudflareST 详细参数配置

#### 基本测速参数

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SPEEDTEST_THREADS` | 200 | 延迟测速线程数 (最多1000) |
| `SPEEDTEST_LATENCY_TIMES` | 4 | 延迟测速次数 |
| `SPEEDTEST_DOWNLOAD_NUM` | 10 | 下载测速数量 |
| `SPEEDTEST_DOWNLOAD_TIME` | 10 | 下载测速时间(秒) |
| `SPEEDTEST_PORT` | 443 | 测速端口 |
| `SPEEDTEST_URL` | - | 自定义测速地址 |

#### 测速模式参数

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SPEEDTEST_HTTPING` | false | 是否使用HTTP模式 (默认TCPing) |
| `SPEEDTEST_HTTP_CODE` | 200 | HTTP模式有效状态码 |
| `SPEEDTEST_COLO` | - | 匹配指定地区 (如：HKG,KHH,NRT) |

#### 过滤条件参数

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SPEEDTEST_LATENCY_MAX` | 9999 | 平均延迟上限(ms) |
| `SPEEDTEST_LATENCY_MIN` | 0 | 平均延迟下限(ms) |
| `SPEEDTEST_LOSS_RATE` | 1.00 | 丢包率上限 (0.00-1.00) |
| `SPEEDTEST_SPEED_MIN` | 0.00 | 下载速度下限(MB/s) |

#### 输出控制参数

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SPEEDTEST_RESULT_NUM` | 10 | 显示结果数量 (0为不显示) |
| `SPEEDTEST_IP_FILE` | ip.txt | IP段数据文件路径 |
| `SPEEDTEST_IP_RANGE` | - | 直接指定IP段 (逗号分隔) |

#### 其他选项

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `SPEEDTEST_DISABLE_DOWNLOAD` | false | 禁用下载测速 |
| `SPEEDTEST_ALL_IP` | false | 测速全部IP (仅IPv4) |
| `SPEEDTEST_DEBUG` | false | 调试模式 |

#### 通知控制参数

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `NOTIFICATION_ENABLE` | true | 是否启用通知 |
| `NOTIFICATION_SUCCESS` | true | 成功时发送通知 |
| `NOTIFICATION_FAILURE` | true | 失败时发送通知 |

#### 下载配置参数

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `CLOUDFLARE_ST_VERSION` | v2.2.5 | CloudflareST 版本 |
| `GITHUB_PROXY_URL` | - | GitHub 代理URL (可选，用于加速下载) |

### 支持的架构

| 架构 | 说明 |
|------|------|
| `linux/amd64` | x86_64 (Intel/AMD 64位) |
| `linux/arm64` | ARM 64位 (Apple M1, 树莓派4等) |
| `linux/arm/v7` | ARM 32位 v7 (树莓派3等) |
| `linux/386` | x86 32位 |

## CI/CD 和自动发布

项目使用 GitHub Actions 自动构建和发布多架构 Docker 镜像：

### 自动触发条件
- 推送到 `main` 或 `master` 分支
- 创建新的 tag (如 `v1.0.0`)
- 手动触发 workflow

### 配置 GitHub Secrets
在 GitHub 仓库设置中添加以下 Secrets：
- `DOCKER_USERNAME` - Docker Hub 用户名
- `DOCKER_PASSWORD` - Docker Hub 密码或访问令牌

### 发布流程
1. 创建新的 git tag：`git tag v1.0.0 && git push origin v1.0.0`
2. GitHub Actions 自动构建多架构镜像
3. 推送到 Docker Hub
4. 创建 GitHub Release

### 目录结构

```
.
├── Dockerfile              # Docker镜像构建文件
├── docker-compose.yml      # Docker Compose配置
├── entrypoint.sh           # 容器启动脚本
├── init.sh                 # 初始化脚本 (下载二进制文件和数据库)
├── start.sh                # 主控脚本 (DNS更新、通知)
├── speedtest.sh            # 测速脚本 (参数拼接、执行测速)
├── result.csv              # 测试结果文件 (挂载卷)
└── cron.log                # 定时任务日志 (挂载卷)
```

## 自定义配置

### 修改配置
编辑 `.env` 文件来修改各种配置：

```bash
# 修改定时任务 (每2小时执行一次)
CRON_SCHEDULE=0 */2 * * *

# 修改CloudflareSpeedTest版本
CLOUDFLARE_ST_VERSION=v2.3.0

# 修改测试参数
TEST_COUNT=300
TIMEOUT=15
```

或者直接编辑 `docker-compose.yml` 中的环境变量。

### 工作流程

1. **定时触发**：根据 `CRON_SCHEDULE` 定时执行 `start.sh`
2. **执行测速**：`start.sh` 调用 `speedtest.sh` 进行速度测试
3. **参数拼接**：`speedtest.sh` 根据环境变量拼接 CloudflareST 参数
4. **解析结果**：`start.sh` 解析测试结果，获取最优IP
5. **DNS更新**：如果最优IP与当前DNS记录不同，自动更新
6. **Telegram通知**：发送测试结果和DNS更新状态到Telegram

### 脚本职责

- **constants.sh**：常量定义文件，包含所有脚本共享的常量、默认值和通用函数
- **entrypoint.sh**：容器启动脚本，调用初始化脚本，设置定时任务
- **init.sh**：初始化脚本，下载 CloudflareST 二进制文件和 IP 地理位置数据库
- **start.sh**：主控脚本，协调整个流程，处理DNS更新和通知
- **speedtest.sh**：专门的测速脚本，负责参数拼接和执行测速

### 通知消息示例

**DNS更新成功**：
```
🚀 Cloudflare DNS 更新成功

📍 域名: example.com
🔄 IP变更: 1.1.1.1 → 1.0.0.1
⚡ 速度: 15.23 ms
⏰ 时间: 2024-01-01 12:00:00
```

**无需更新**：
```
✅ Cloudflare 速度测试完成

📍 域名: example.com
🎯 最优IP: 1.1.1.1
⚡ 速度: 15.23 ms
💡 DNS记录无需更新
⏰ 时间: 2024-01-01 12:00:00
```

## 常用命令

```bash
# 启动容器
docker-compose up -d

# 查看实时日志
docker-compose logs -f

# 停止容器
docker-compose down

# 手动执行一次测试
docker-compose exec cloudflare-speedtest /app/speedtest.sh

# 进入容器
docker-compose exec cloudflare-speedtest /bin/bash
```

## 文件说明

- `result.csv`: 最新的测试结果（每次覆盖）
- `cron.log`: 定时任务执行日志

## 注意事项

1. 首次运行时会自动下载IP地理位置数据库
2. 容器会自动清理7天前的旧结果文件
3. 确保有足够的磁盘空间存储日志和结果文件
4. 建议根据网络环境调整测试参数

## 故障排除

### 查看日志
```bash
# 查看容器日志
docker-compose logs cloudflare-speedtest

# 查看定时任务日志
cat cron.log

# 查看测试结果
cat result.csv
```

### 重新构建镜像
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

## 代码优化记录

本项目已完成5轮全面代码审查和优化：

### 优化内容
1. **第1轮**：建立项目结构和依赖关系图谱
2. **第2轮**：移除未使用的代码和函数
   - 删除 `test_dns.sh`（包含硬编码凭据，从未被调用）
   - 移除 `test_notification()` 函数（未使用）
   - 删除 `test.sh`（开发测试工具，生产环境不需要）
   - 清理调试日志语句
3. **第3轮**：代码重复分析和优化
   - 创建 `call_cloudflare_api()` 统一API调用函数
   - 创建 `call_telegram_api()` 统一Telegram API调用函数
   - 重构所有DNS管理和通知函数使用统一接口
4. **第4轮**：配置文件和文档一致性检查
   - 修复README中参数名不一致问题（`CLOUDFLARE_RECORD_NAME` → `CLOUDFLARE_DOMAIN`）
   - 清理docker-compose.yml中的硬编码敏感信息
5. **第5轮**：最终清理和优化确认
   - 验证所有函数导出正确
   - 确认所有新函数被正确调用
   - 检查模块依赖关系完整性

### 安全改进
- 移除配置文件中的硬编码凭据
- 统一API调用错误处理
- 改进日志记录和调试信息

## 许可证

本项目基于 MIT 许可证开源。

## 相关链接

- [CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest)
- [qqwry.dat](https://github.com/metowolf/qqwry.dat)
