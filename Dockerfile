# CodeBuddy Code —— 容器镜像（--serve 形态，功能最全）
#
# 这个 Dockerfile 是给 GitHub Actions 用的：
#   runner 在境外，直连 Docker Hub 没有障碍，所以 FROM 用官方 node:20-bookworm，
#   不需要任何国内加速域名，npm 也走官方源（比国内镜像快）。
#
# 构建产物会由 workflow 存成 codebuddy-serve-amd64.tar.gz，
# 下载后到 NAS 上 docker load 即可，NAS 全程不需要联网拉镜像。
#
# 依据官方文档：
#   cnb.cool/codebuddy/codebuddy-code/-/blob/main/docs/devcontainer.md
#   cnb.cool/codebuddy/codebuddy-code/-/blob/main/docs/http-api.md

FROM node:20-bookworm

# 开发工具：取官方 devcontainer apt 清单的子集
# （去掉 sudo/zsh/gh/iptables/ipset 这些 devcontainer 专属项，补 ripgrep 给 AI 搜代码）
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl wget ca-certificates \
        ripgrep jq less vim nano procps unzip gnupg2 man-db dnsutils \
        openssh-client \
    && rm -rf /var/lib/apt/lists/*

# 最新版 CodeBuddy Code —— 「功能最全」= latest
ARG CODEBUDDY_CODE_VERSION=latest
RUN npm install -g @tencent-ai/codebuddy-code@${CODEBUDDY_CODE_VERSION} \
    && codebuddy --version

ENV LANG=C.UTF-8
ENV LANGUAGE=C.UTF-8
ENV NODE_OPTIONS=--max-old-space-size=4096
ENV CODEBUDDY_CONFIG_DIR=/root/.codebuddy

WORKDIR /workspace
EXPOSE 8080

# --serve = HTTP API 形态（REST /api/v1/* + ACP + webhooks + jobs + daemon
#           + 定时任务 + PTY + 文件系统），是功能最全的形态。
# 绑 0.0.0.0 时官方强制开启密码认证，密码首次启动生成、写在 settings.json 并打印在日志。
CMD ["codebuddy", "--serve", "--port", "8080", "--host", "0.0.0.0"]
