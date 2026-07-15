# EasyBot + NapCat

直接使用 [EasyBot Docker](https://github.com/easybot-team/easybot-docker) 和 [NapCat Docker](https://github.com/NapNeko/NapCat-Docker) 的构建逻辑，在一个 `linux/amd64` 容器中运行 EasyBot 与 NapCat。

## 运行

将 `<owner>` 替换为当前 GitHub 用户或组织名：

```bash
docker run -d \
  --name easybot-napcat \
  --restart unless-stopped \
  -e WEBUI_TOKEN=change-me \
  -p 5000:5000 \
  -p 26990:26990 \
  -p 6099:6099 \
  -p 3000:3000 \
  -p 3001:3001 \
  -v easybot-appdata:/opt/easybot/appdata \
  -v easybot-logs:/opt/easybot/logs \
  -v napcat-config:/app/napcat/config \
  -v napcat-qq:/app/.config/QQ \
  ghcr.io/<owner>/ebnc:latest
```

NapCat 环境变量 `ACCOUNT`、`MODE`、`WEBUI_PREFIX`、`NAPCAT_UID` 和 `NAPCAT_GID` 可按需添加。

## 自动更新

GitHub Actions 每 6 小时检查一次上游。更新通过构建和启动验证后，会自动提交 Dockerfile 并发布公开 GHCR 镜像：

- `latest`
- `<仓库 commit前8位>`（不可变回滚标签）

如需强制重新发布，可手动运行 `Sync upstreams and publish image` workflow。
