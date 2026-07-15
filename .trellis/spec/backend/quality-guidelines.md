# Quality Guidelines

> Code quality standards for backend development.

---

## Overview

<!--
Document your project's quality standards here.

Questions to answer:
- What patterns are forbidden?
- What linting rules do you enforce?
- What are your testing requirements?
- What code review standards apply?
-->

(To be filled by the team)

---

## Forbidden Patterns

<!-- Patterns that should never be used and why -->

(To be filled by the team)

---

## Required Patterns

### Scenario: Publish immutable GHCR rollback tags

#### 1. Scope / Trigger

- Trigger: a workflow publishes both a moving `latest` tag and a rollback tag to GHCR.

#### 2. Signatures

- Image name: `ghcr.io/<owner>/ebnc`.
- Rollback tag: `<repository-commit[:8]>`.
- Probe command: `docker buildx imagetools inspect <image>:<rollback-tag>`.

#### 3. Contracts

- `latest` may move after build validation succeeds.
- A rollback tag must be derived from the repository commit containing all locked upstream inputs.
- An existing rollback tag must never be included in a later push.

#### 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Probe succeeds | Publish only `latest` |
| Probe explicitly reports `not found` or `manifest unknown` | Publish `latest` and the rollback tag |
| Probe fails for any other reason | Stop before publishing |

#### 5. Good/Base/Bad Cases

- Good: a new upstream combination publishes both tags.
- Base: a manual rebuild publishes `latest` while preserving the existing rollback tag.
- Bad: a timeout or authentication failure is treated as a missing tag.

#### 6. Tests Required

- Run `actionlint` with ShellCheck integration enabled.
- Verify the tag probe has explicit existing, missing, and error branches.
- Verify the publish action consumes the computed tag list rather than reconstructing tags.

#### 7. Wrong vs Correct

Wrong:

```bash
docker buildx imagetools inspect "$image:$tag" || publish_rollback=true
```

Correct:

```bash
if docker buildx imagetools inspect "$image:$tag"; then
  publish_rollback=false
elif grep -Eqi 'not found|manifest unknown' "$inspect_error"; then
  publish_rollback=true
else
  exit 1
fi
```

### Scenario: Preserve upstream runtime permissions and readiness

#### 1. Scope / Trigger

- Trigger: upstream image build steps are inlined into this repository instead of inheriting the upstream image.

#### 2. Signatures

- Permission initialization: `chmod 0755 /opt/easybot/*`.
- Required executables: `EasyBot`, `EasyBot.WebUI`, and `EasyBot.WebUI.Updater`.
- EasyBot readiness probe: HTTP connection to `http://127.0.0.1:5000/`.

#### 3. Contracts

- Copy upstream permission initialization as well as files and packages.
- Fail the image build unless all EasyBot launch-chain executables are executable.
- A live launcher PID is insufficient readiness evidence; the HTTP service must respond.

#### 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| A launch-chain file is not executable | Fail during image build |
| Launcher PID exists but HTTP is unavailable | Keep waiting, then fail the smoke check |
| Both service PIDs exist and EasyBot HTTP responds | Pass startup validation |

#### 5. Good/Base/Bad Cases

- Good: all launch-chain files are executable and port 5000 responds.
- Base: EasyBot needs initialization time, so the smoke check waits up to 120 seconds.
- Bad: `EasyBot` is executable but its child `EasyBot.WebUI` returns `Permission denied`.

#### 6. Tests Required

- Run Hadolint and actionlint with ShellCheck integration.
- Assert the Dockerfile contains executable checks for the complete EasyBot launch chain.
- Assert startup validation checks both PIDs and the EasyBot HTTP endpoint.

#### 7. Wrong vs Correct

Wrong:

```dockerfile
RUN chmod 0755 /opt/easybot/EasyBot
```

Correct:

```dockerfile
RUN chmod 0755 /opt/easybot/* \
    && test -x /opt/easybot/EasyBot \
    && test -x /opt/easybot/EasyBot.WebUI \
    && test -x /opt/easybot/EasyBot.WebUI.Updater
```

### Scenario: Lock Linux QQ from the official live configuration

#### 1. Scope / Trigger

- Trigger: the image installs Linux QQ, whose historical direct download URLs may be removed.

#### 2. Signatures

- Discovery source: `https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js`.
- Locked inputs: `QQ_DEB_URL` and `QQ_VERSION`.

#### 3. Contracts

- Discover the amd64 deb URL from `x64DownloadUrl.deb`, not from NapCat-Docker's historical Dockerfile.
- Accept only HTTPS URLs on approved Tencent QQ download domains.
- Require the version in the URL filename to equal `QQ_VERSION`.

#### 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Official config cannot be parsed | Stop before editing Dockerfile |
| URL host/path or architecture is invalid | Reject in `update-upstreams.sh` |
| URL and version disagree | Reject in `update-upstreams.sh` |
| Deb download returns an error | Fail the image build; do not commit or publish |

#### 5. Good/Base/Bad Cases

- Good: official config yields a matching amd64 deb URL and semantic version.
- Base: a new official URL updates both locked Dockerfile arguments.
- Bad: continue retrying a permanently removed NapCat-Docker URL that returns 404.

#### 6. Tests Required

- Parse the current official configuration and assert exactly one URL/version pair.
- Verify updater idempotence with the discovered pair.
- Verify invalid domains, non-amd64 files, and mismatched versions fail.

#### 7. Wrong vs Correct

Wrong:

```dockerfile
ARG QQ_DOWNLOAD_ID=f9cbaab2
```

Correct:

```dockerfile
ARG QQ_DEB_URL=https://qqdl.gtimg.cn/qqfile/.../QQ_3.2.31_260710_amd64_01.deb
ARG QQ_VERSION=3.2.31
```


---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
