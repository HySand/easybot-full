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

- Rollback tag: `easybot-<easybot-commit[:8]>-napcat-<release>-docker-<napcat-docker-commit[:8]>`.
- Probe command: `docker buildx imagetools inspect <image>:<rollback-tag>`.

#### 3. Contracts

- `latest` may move after build validation succeeds.
- A rollback tag must include every upstream repository revision that can change image contents.
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


---

## Testing Requirements

<!-- What level of testing is expected -->

(To be filled by the team)

---

## Code Review Checklist

<!-- What reviewers should check -->

(To be filled by the team)
