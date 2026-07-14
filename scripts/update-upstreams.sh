#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

usage() {
  printf 'Usage: %s <dockerfile> <dotnet-image> <easybot-commit> <chrome-version> <napcat-docker-commit> <napcat-version> <qq-download-id> <qq-version>\n' "$0" >&2
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
qq_download_id=$7
qq_version=$8

[[ -f "$dockerfile" ]] || die "Dockerfile not found: $dockerfile"
[[ "$dotnet_image" =~ ^mcr\.microsoft\.com/dotnet/aspnet:[0-9]+\.[0-9]+\.[0-9]+-jammy-amd64$ ]] \
  || die 'invalid .NET image'
[[ "$easybot_commit" =~ ^[0-9a-f]{40}$ ]] || die 'invalid EasyBot commit'
[[ "$chrome_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'invalid Chrome version'
[[ "$napcat_docker_commit" =~ ^[0-9a-f]{40}$ ]] || die 'invalid NapCat-Docker commit'
[[ "$napcat_version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
  || die 'NapCat version must be a stable vMAJOR.MINOR.PATCH tag'
[[ "$qq_download_id" =~ ^[0-9a-f]{8}$ ]] || die 'invalid QQ download identifier'
[[ "$qq_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]] || die 'invalid QQ version'

dotnet_pattern='^ARG DOTNET_IMAGE=mcr\.microsoft\.com/dotnet/aspnet:[0-9]+\.[0-9]+\.[0-9]+-jammy-amd64$'
easybot_pattern='^ARG EASYBOT_COMMIT=[0-9a-f]{40}$'
chrome_pattern='^ARG CHROME_VERSION=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
napcat_docker_pattern='^ARG NAPCAT_DOCKER_COMMIT=[0-9a-f]{40}$'
napcat_pattern='^ARG NAPCAT_VERSION=v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
qq_id_pattern='^ARG QQ_DOWNLOAD_ID=[0-9a-f]{8}$'
qq_version_pattern='^ARG QQ_VERSION=[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$'

patterns=(
  "$dotnet_pattern"
  "$easybot_pattern"
  "$chrome_pattern"
  "$napcat_docker_pattern"
  "$napcat_pattern"
  "$qq_id_pattern"
  "$qq_version_pattern"
)
labels=(
  '.NET image'
  'EasyBot commit'
  'Chrome version'
  'NapCat-Docker commit'
  'NapCat version'
  'QQ download identifier'
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
  "ARG QQ_DOWNLOAD_ID=${qq_download_id}"
  "ARG QQ_VERSION=${qq_version}"
)

temporary_file=$(mktemp "${dockerfile}.tmp.XXXXXX")
trap 'rm -f "$temporary_file"' EXIT

sed -E \
  -e "s#${dotnet_pattern}#${lines[0]}#" \
  -e "s#${easybot_pattern}#${lines[1]}#" \
  -e "s#${chrome_pattern}#${lines[2]}#" \
  -e "s#${napcat_docker_pattern}#${lines[3]}#" \
  -e "s#${napcat_pattern}#${lines[4]}#" \
  -e "s#${qq_id_pattern}#${lines[5]}#" \
  -e "s#${qq_version_pattern}#${lines[6]}#" \
  "$dockerfile" > "$temporary_file"

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
