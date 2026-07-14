# 自动构建并发布 EasyBot + NapCat 组合镜像

## Goal

提供一个可公开匿名拉取的 `linux/amd64` 单容器镜像，在同一容器内同时运行 EasyBot 与 NapCat。仓库直接合并两个上游的构建逻辑，不依赖上游成品 Docker 镜像；GitHub Actions 自动同步上游版本、验证构建并发布到 GHCR。

## Background

- `easybot-team/easybot-docker` 将 stable 程序文件保存在 `boot/stable`，Dockerfile 指定 .NET ASP.NET 基础镜像、桌面依赖和 Chrome Headless Shell 版本。
- `NapNeko/NapCat-Docker` 的构建逻辑从 NapCatQQ release 下载 `NapCat.Shell.zip`，安装指定 Linux QQ，并复制上游入口脚本和模板。
- 组合构建以 EasyBot 上游使用的 .NET 基础镜像为底层，直接下载两个仓库的锁定 commit 和 NapCat release 产物，再安装 QQ、Chrome 与合并后的系统依赖。

## Requirements

- R1：Dockerfile 不得 `FROM miuxue/easybot` 或 `FROM mlikiowa/napcat-docker`，必须直接实现两个上游的构建步骤。
- R2：Dockerfile 锁定 .NET 基础镜像标签、EasyBot commit、Chrome 版本、NapCat-Docker commit、NapCat release、QQ 下载标识和 QQ 版本。
- R3：EasyBot 程序安装到 `/opt/easybot`；NapCat、模板与 QQ 保持上游的 `/app`、`/opt/QQ` 路径约定。
- R4：单容器同时运行 EasyBot 与 NapCat；任一主进程退出时终止另一进程，正确处理 SIGTERM/SIGINT 并回收子进程。
- R5：保留双方配置/日志卷和常用端口，当前仅发布 `linux/amd64`。
- R6：GitHub Actions 每 6 小时及手动触发，查询两个仓库的 main commit 和 NapCatQQ latest stable release，并从锁定 commit 的上游 Dockerfile 解析 .NET、Chrome 与 QQ 版本。
- R7：上游无变化的定时运行不提交、不发布；发生变化时先更新 Dockerfile、构建并启动验证，成功后直接提交默认分支。
- R8：发布公开 `ghcr.io/<owner>/<repo>:latest`，并发布 `easybot-<commit前8位>-napcat-v<版本>` 不可变回滚标签。
- R9：版本替换必须严格校验格式与唯一匹配；API、下载、解析或构建失败时不得提交或覆盖 `latest`。
- R10：保留 keepalive job，使用最小 GitHub Token 权限，不提交凭据或测试代码。

## Acceptance Criteria

- [ ] Dockerfile 只使用 Microsoft .NET 基础镜像，直接下载并安装 EasyBot stable、NapCat Shell、Linux QQ、Chrome、上游 NapCat 入口和模板。
- [ ] 所有上游版本输入均在 Dockerfile 中可审计、可由脚本唯一更新，并由 commit/release/version 锁定。
- [ ] 组合容器的目录、卷、端口、环境变量与双进程生命周期保持正确。
- [ ] workflow 能发现两个上游更新并同步 .NET、Chrome、QQ 等构建参数；解析不到唯一合法值时明确失败。
- [ ] 无变化、验证失败、Git push 失败和发布失败的行为符合需求。
- [ ] GHCR 同时发布公开 `latest` 与基于 EasyBot commit/NapCat release 的不可变标签。
- [ ] actionlint、ShellCheck、Hadolint、版本脚本幂等与敏感信息检查通过。

## Out of Scope

- 发布 arm64 组合镜像。
- 修改两个上游仓库或重新编译 EasyBot/NapCat 源码；本仓库使用它们已经发布的程序文件。
- Docker Compose 双容器方案。
- 提交自动化测试文件或 fixture；验证使用临时命令和 workflow 构建门禁。
