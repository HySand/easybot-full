# Technical Design

## Build Architecture

最终镜像仅使用 EasyBot 上游指定的 `mcr.microsoft.com/dotnet/aspnet:<version>-jammy-amd64` 作为基础层。

Dockerfile 的版本契约由以下 ARG 组成：

- `DOTNET_IMAGE`
- `EASYBOT_COMMIT`
- `CHROME_VERSION`
- `NAPCAT_DOCKER_COMMIT`
- `NAPCAT_VERSION`
- `QQ_DEB_URL`
- `QQ_VERSION`

构建流程：

1. 安装 EasyBot full 与 NapCat base 所需依赖，并安装 `tini`。
2. 下载 `easybot-team/easybot-docker` 的锁定 commit archive，将 `boot/stable` 复制到 `/opt/easybot`，并按上游行为为顶层启动文件补齐执行权限。
3. 按锁定 Chrome 版本下载 Chrome Headless Shell 到 EasyBot 预期目录。
4. 下载 `NapNeko/NapCat-Docker` 的锁定 commit archive，复制 `entrypoint.sh` 和 `templates` 到 `/app`。
5. 下载锁定 NapCatQQ release 的 `NapCat.Shell.zip`。
6. 从腾讯 Linux QQ 官方配置锁定 amd64 deb URL 与版本并安装，再写入 `loadNapCat.js`、修改 QQ package main。
7. 使用本仓库组合入口通过 `tini` 同时启动上游 NapCat 入口和 EasyBot。

所有 archive、zip 和 deb 在同一 RUN 层使用后删除，避免进入最终镜像。

## Runtime Layout

- EasyBot：`/opt/easybot`
- NapCat：`/app/napcat`
- NapCat release zip、入口与模板：`/app`
- QQ：`/opt/QQ`
- 组合监督入口：`/usr/local/bin/easybot-napcat-entrypoint`

卷：`/opt/easybot/appdata`、`/opt/easybot/logs`、`/app/napcat/config`、`/app/.config/QQ`。

暴露端口：EasyBot Web `5000`、EasyBot WebSocket `26990`、NapCat WebUI `6099`。

## Version Discovery

workflow 使用 GitHub API 获取：

- `easybot-team/easybot-docker` main commit。
- `NapNeko/NapCat-Docker` main commit。
- `NapNeko/NapCatQQ` latest stable release tag。

随后读取锁定 commit 的原始 Dockerfile与腾讯官方 Linux QQ 配置：

- 从 EasyBot Dockerfile 唯一解析 .NET base image 与 Chrome 四段版本。
- 从 `linuxConfig.js` 唯一解析 amd64 deb URL 与 QQ 版本，并校验官方域名、文件格式和 URL 内版本一致性。

`scripts/update-upstreams.sh` 集中验证并更新全部七个 ARG。任何字段缺失、重复或格式非法都会中止。

## Workflow

定时/手动运行依次执行发现、更新、Buildx 构建、双进程 PID 与 EasyBot HTTP 就绪验证、bot 提交、GHCR 发布和 Public 可见性检查。各上游版本保存在 Dockerfile 和 OCI labels 中。

镜像名固定为简短的 `ghcr.io/<owner>/ebnc`。不可变标签只使用构建所对应仓库 commit 的前 8 位；发布前检查远端标签，已存在时只更新 `latest`，探测错误则停止发布，确保回滚标签不会被覆盖。

keepalive job 独立运行，使用 `actions: write` 和 checkout 所需的 `contents: read`。

## Failure Boundaries

- 上游 API、archive/release/QQ/Chrome 下载或解析失败：构建前失败，不改默认分支。
- 构建/启动失败：不提交、不发布。
- Git push 失败：不发布。
- GHCR 发布失败：可用手动强制发布恢复当前锁定版本。
- Public API 受组织策略限制：镜像可能先保持 private，管理员手动公开后重跑可通过幂等检查。
