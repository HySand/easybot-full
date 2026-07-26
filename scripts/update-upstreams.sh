#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

usage() {
  printf 'Usage: %s <dockerfile> <dotnet-image> <easybot-commit> <chrome-version> <napcat-docker-commit> <napcat-version> <qq-version> <qq-url-sha256>\n' "$0" >&2
}

die() {
  printf 'update-upstreams: %s\n' "$*" >&2
  exit 1
}

if [[ "$#" -ne 8 ]]; then
  usage
  exit 2
fi

dockerfile=$1
dotnet_image=$2
easybot_commit=$3
chrome_version=$4
napcat_docker_commit=$5
napcat_version=$6
qq_version=$7
qq_url_sha256=$8

[[ -f "$dockerfile" ]] || die "Dockerfile not found: $dockerfile"
[[ "$dotnet_image" =~ ^mcr\.microsoft\.com/dotnet/aspnet:[0-9]+\.[0-9]+\.[0-9]+-jammy-amd64$ ]] \
  || die 'invalid .NET image'
[[ "$easybot_commit" =~ ^[0-9a-f]{40}$ ]] || die 'invalid EasyBot commit'
[[ "$chrome_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'invalid Chrome version'
[[ "$napcat_docker_commit" =~ ^[0-9a-f]{40}$ ]] || die 'invalid NapCat-Docker commit'
[[ "$napcat_version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
  || die 'NapCat version must be a stable vMAJOR.MINOR.PATCH tag'
[[ "$qq_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'invalid QQ version'
[[ "$qq_url_sha256" =~ ^[0-9a-f]{64}$ ]] || die 'invalid QQ URL SHA-256'

dotnet_pattern='^ARG DOTNET_IMAGE=mcr\.microsoft\.com/dotnet/aspnet:[0-9]+\.[0-9]+\.[0-9]+-jammy-amd64$'
easybot_pattern='^ARG EASYBOT_COMMIT=[0-9a-f]{40}$'
chrome_pattern='^ARG CHROME_VERSION=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
napcat_docker_pattern='^ARG NAPCAT_DOCKER_COMMIT=[0-9a-f]{40}$'
napcat_pattern='^ARG NAPCAT_VERSION=v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
qq_config_pattern='^ARG QQ_CONFIG_URL=https://cdn-go\.cn/qq-web/im\.qq\.com_new/latest/rainbow/linuxConfig\.js$'
qq_legacy_url_pattern='^ARG QQ_DEB_URL=https://(qqdl\.gtimg\.cn|dldir1(v6)?\.qq\.com)/qqfile/[A-Za-z0-9._/-]+/QQ_[0-9]+\.[0-9]+\.[0-9]+_[0-9]{6}_amd64_[0-9]+\.deb$'
qq_version_pattern='^ARG QQ_VERSION=[0-9]+\.[0-9]+\.[0-9]+$'
qq_url_sha256_pattern='^ARG QQ_DEB_URL_SHA256=[0-9a-f]{64}$'

qq_config_count=$(grep -Ec "$qq_config_pattern" "$dockerfile" || true)
qq_legacy_url_count=$(grep -Ec "$qq_legacy_url_pattern" "$dockerfile" || true)
if [[ "$qq_config_count" -eq 1 && "$qq_legacy_url_count" -eq 0 ]]; then
  qq_source_pattern=$qq_config_pattern
elif [[ "$qq_config_count" -eq 0 && "$qq_legacy_url_count" -eq 1 ]]; then
  qq_source_pattern=$qq_legacy_url_pattern
else
  die "expected exactly one QQ config URL or legacy QQ deb URL, found config=$qq_config_count legacy=$qq_legacy_url_count"
fi

qq_url_sha256_count=$(grep -Ec "$qq_url_sha256_pattern" "$dockerfile" || true)
if [[ "$qq_url_sha256_count" -gt 1 ]]; then
  die "expected at most one QQ URL SHA-256 line, found $qq_url_sha256_count"
fi
if [[ "$qq_source_pattern" == "$qq_config_pattern" && "$qq_url_sha256_count" -ne 1 ]]; then
  die "expected exactly one QQ URL SHA-256 line for the current QQ config format, found $qq_url_sha256_count"
fi

patterns=(
  "$dotnet_pattern"
  "$easybot_pattern"
  "$chrome_pattern"
  "$napcat_docker_pattern"
  "$napcat_pattern"
  "$qq_source_pattern"
  "$qq_version_pattern"
)
labels=(
  '.NET image'
  'EasyBot commit'
  'Chrome version'
  'NapCat-Docker commit'
  'NapCat version'
  'QQ config URL or legacy QQ deb URL'
  'QQ version'
)

for index in "${!patterns[@]}"; do
  count=$(grep -Ec "${patterns[$index]}" "$dockerfile" || true)
  [[ "$count" -eq 1 ]] \
    || die "expected exactly one ${labels[$index]} line, found $count"
done

lines=(
  "ARG DOTNET_IMAGE=${dotnet_image}"
  "ARG EASYBOT_COMMIT=${easybot_commit}"
  "ARG CHROME_VERSION=${chrome_version}"
  "ARG NAPCAT_DOCKER_COMMIT=${napcat_docker_commit}"
  "ARG NAPCAT_VERSION=${napcat_version}"
  'ARG QQ_CONFIG_URL=https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js'
  "ARG QQ_VERSION=${qq_version}"
  "ARG QQ_DEB_URL_SHA256=${qq_url_sha256}"
)

temporary_file=$(mktemp "${dockerfile}.tmp.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

sed_args=(
  -e "s#${dotnet_pattern}#${lines[0]}#"
  -e "s#${easybot_pattern}#${lines[1]}#"
  -e "s#${chrome_pattern}#${lines[2]}#"
  -e "s#${napcat_docker_pattern}#${lines[3]}#"
  -e "s#${napcat_pattern}#${lines[4]}#"
  -e "s#${qq_source_pattern}#${lines[5]}#"
  -e "s#${qq_version_pattern}#${lines[6]}#"
)
if [[ "$qq_url_sha256_count" -eq 1 ]]; then
  sed_args+=( -e "s#${qq_url_sha256_pattern}#${lines[7]}#" )
fi

sed -E "${sed_args[@]}" \
  "$dockerfile" > "$temporary_file"

if [[ "$qq_url_sha256_count" -eq 0 ]]; then
  sed -i -E "/^ARG QQ_VERSION=/a ${lines[7]}" "$temporary_file"
fi

for line in "${lines[@]}"; do
  grep -Fqx "$line" "$temporary_file" \
    || die "verification failed after replacement: $line"
done

if cmp -s "$dockerfile" "$temporary_file"; then
  printf 'Upstream build inputs are already current.\n'
  exit 0
fi

mv "$temporary_file" "$dockerfile"
trap - EXIT
printf 'Updated EasyBot %s, NapCat %s and upstream build inputs.\n' \
  "$easybot_commit" "$napcat_version"
