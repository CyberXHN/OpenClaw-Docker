# 以官方原版 OpenClaw 镜像为基础（请根据实际情况替换镜像名和标签）
ARG UPSTREAM_VERSION
FROM ghcr.io/openclaw/openclaw:${UPSTREAM_VERSION}

# 切换到 root 用户，用于安装系统依赖和修改文件
USER root

# 1. 安装 Xvfb（无界面浏览器运行必需的虚拟帧缓存）
# 2. 配置 Playwright 浏览器安装路径
# 3. 调用 Playwright 安装 Chromium 及运行依赖
# 4. 修正浏览器缓存目录权限（适配官方镜像的 node 用户运行）
# 5. 清理 apt 缓存，减小镜像体积
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends xvfb && \
    mkdir -p /home/node/.cache/ms-playwright && \
    PLAYWRIGHT_BROWSERS_PATH=/home/node/.cache/ms-playwright \
    node /app/node_modules/playwright-core/cli.js install --with-deps chromium && \
    chown -R node:node /home/node/.cache/ms-playwright && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# 切换回官方镜像默认的 node 用户（安全加固）
USER node

# 保持与官方镜像一致的启动命令和健康检查
HEALTHCHECK --interval=3m --timeout=10s --start-period=15s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:18789/healthz').then((r)=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]