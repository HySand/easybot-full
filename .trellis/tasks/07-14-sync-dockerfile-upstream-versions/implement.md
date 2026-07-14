# Implementation Plan

## Checklist

- [x] 调研 EasyBot 与 NapCat 当前上游构建脚本和 main commit。
- [x] 重写 Dockerfile，移除两个上游成品镜像引用并合并下载/安装逻辑。
- [x] 重写版本更新脚本以管理七个构建参数。
- [x] 更新 workflow 的发现、提交信息、标签和 OCI labels。
- [x] 保留双进程入口、GHCR 发布、Public 可见性和 keepalive 行为。
- [x] 更新精简 README 的构建来源描述。
- [x] 运行 Bash、更新脚本、actionlint、ShellCheck、Hadolint、格式和敏感信息检查。

## Validation

- 本机没有 Docker；实际 Buildx 构建和双进程 smoke 由 workflow 在提交/发布前强制执行。
- 不新增测试代码；更新脚本行为在系统临时目录验证，产物随即删除。
- `actionlint 1.7.12`（含 ShellCheck 集成）、`ShellCheck 0.11.0`、`Hadolint 2.14.0`、Bash 语法、版本替换幂等/非法输入、上游解析、下载可达性、空白与敏感信息检查均通过。
