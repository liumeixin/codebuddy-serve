# codebuddy-serve

在 GitHub Actions 上构建 **CodeBuddy Code** 容器镜像（`--serve` 形态），产出两条路：

| 方式 | 怎么用 |
|---|---|
| **① 直接拉镜像**（推荐） | `image: ghcr.io/liumeixin/codebuddy-serve:latest` |
| ② 离线导入 | 下载 Release 里的 `tar.gz` → `docker load` |

**为什么存在这个仓库**：目标 NAS 连不上 Docker Hub（国内各类加速源也大面积失效），
但 GitHub 的 runner 在境外、直连没有问题。于是把构建搬到云端。

---

## ① 直接拉镜像（推荐）

```yaml
services:
  codebuddy:
    image: ghcr.io/liumeixin/codebuddy-serve:latest
    container_name: codebuddy
    restart: unless-stopped
    stdin_open: true
    tty: true
    working_dir: /workspace
    ports:
      - "8095:8080"
    volumes:
      - ./workspace:/workspace
      - ./data/config:/root/.codebuddy
      - ./data/auth:/root/.local/share/CodeBuddyExtension
    environment:
      - TZ=Asia/Shanghai
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: "2.0"
```

```bash
mkdir -p workspace data/config data/auth
docker compose up -d
```

更新镜像：

```bash
docker compose pull && docker compose up -d
```

> ⚠️ 前提：这个包必须是 **public**（GitHub 新建的 container 包默认 private，且
> **可见性不会继承仓库**，即使仓库已公开包仍是私有的）。
>
> 若 `docker pull` 报 `unauthorized`，登录 GitHub 后打开：
> `https://github.com/users/liumeixin/packages/container/codebuddy-serve/settings`
> → 页面底部 **Danger Zone** → **Change visibility** → 选 **Public** → 输入包名
> `codebuddy-serve` → 确认。
>
> 注意两点：
> 1. 设置页路径**不带** `/package/` 段（带 `package/` 的是包首页，后面接 `/settings` 会 404）。
> 2. 包还是私有时，未登录访问这个链接也是 404 —— 必须先登录 liumeixin 账号。
>
> GitHub 的 REST API **没有**修改 container 包可见性的端点（对已公开的包 PATCH 同样返回 404），只能网页操作。

---

## ② 离线导入

固定下载地址：

```
https://github.com/liumeixin/codebuddy-serve/releases/download/image-latest/codebuddy-serve-amd64.tar.gz
```

```bash
curl -L -O https://github.com/liumeixin/codebuddy-serve/releases/download/image-latest/codebuddy-serve-amd64.tar.gz
docker load -i codebuddy-serve-amd64.tar.gz
```

NAS 上把 compose 改成只有 `image:`、没有 `build:`，并加 `pull_policy: never`。

---

## 登录 + 取密码（两种方式通用）

```bash
# 扫码登录（终端会打印一个外部登录地址，用电脑浏览器打开）
docker exec -it codebuddy codebuddy

# 取网关密码（--serve 绑 0.0.0.0 时官方强制密码认证）
docker logs codebuddy 2>&1 | grep -i -A2 password
```

调 API 时两个头都要带：

```bash
curl -H "X-CodeBuddy-Request: 1" \
     -H "Authorization: Bearer <密码>" \
     http://<NAS_IP>:8095/api/v1/health
```

Swagger：`http://<NAS_IP>:8095/api/docs`

---

## 镜像里有什么

| 项 | 值 |
|---|---|
| 基础镜像 | `node:20-bookworm`（Debian 12） |
| CodeBuddy Code | `@tencent-ai/codebuddy-code@latest` |
| 平台 | `linux/amd64` |
| 启动命令 | `codebuddy --serve --port 8080 --host 0.0.0.0` |
| 附带工具 | git / curl / wget / ripgrep / jq / vim / nano / unzip / ssh-client 等 |

`--serve` 是功能最全的形态，开放：REST API、ACP、webhooks、jobs、daemon、定时任务、PTY、文件系统。

---

## 手动触发构建

Actions 页面 → `Build CodeBuddy image` → `Run workflow`。

想升级 CodeBuddy 版本，重跑一次即可（`latest` 会拉到当时最新）。

---

## 安全提示

🔴 **`--serve` 的 `/api/v1/envs` 会吐出容器的全部环境变量。**
这个容器**绝不能直接暴露到公网**。要走公网必须套反向代理 + 强认证。
