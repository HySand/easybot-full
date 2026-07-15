#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

usage() {
  printf 'Usage: %s <dockerfile> <dotnet-image> <easybot-commit> <chrome-version> <napcat-docker-commit> <napcat-version> <qq-deb-url> <qq-version>\n' "$0" >&2
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
qq_deb_url=$7
qq_version=$8

[[ -f "$dockerfile" ]] || die "Dockerfile not found: $dockerfile"
[[ "$dotnet_image" =~ ^mcr\.microsoft\.com/dotnet/aspnet:[0-9]+\.[0-9]+\.[0-9]+-jammy-amd64$ ]] \
  || die 'invalid .NET image'
[[ "$easybot_commit" =~ ^[0-9a-f]{40}$ ]] || die 'invalid EasyBot commit'
[[ "$chrome_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'invalid Chrome version'
[[ "$napcat_docker_commit" =~ ^[0-9a-f]{40}$ ]] || die 'invalid NapCat-Docker commit'
[[ "$napcat_version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
  || die 'NapCat version must be a stable vMAJOR.MINOR.PATCH tag'
[[ "$qq_deb_url" =~ ^https://(qqdl\.gtimg\.cn|dldir1(v6)?\.qq\.com)/qqfile/[A-Za-z0-9._/-]+/QQ_[0-9]+\.[0-9]+\.[0-9]+_[0-9]{6}_amd64_[0-9]+\.deb$ ]] \
  || die 'invalid official QQ amd64 deb URL'
[[ "$qq_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die 'invalid QQ version'
[[ "$qq_deb_url" == *"/QQ_${qq_version}_"* ]] || die 'QQ URL and version do not match'

dotnet_pattern='^ARG DOTNET_IMAGE=mcr\.microsoft\.com/dotnet/aspnet:[0-9]+\.[0-9]+\.[0-9]+-jammy-amd64$'
easybot_pattern='^ARG EASYBOT_COMMIT=[0-9a-f]{40}$'
chrome_pattern='^ARG CHROME_VERSION=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
napcat_docker_pattern='^ARG NAPCAT_DOCKER_COMMIT=[0-9a-f]{40}$'
napcat_pattern='^ARG NAPCAT_VERSION=v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
qq_url_pattern='^ARG QQ_DEB_URL=https://(qqdl\.gtimg\.cn|dldir1(v6)?\.qq\.com)/qqfile/[A-Za-z0-9._/-]+/QQ_[0-9]+\.[0-9]+\.[0-9]+_[0-9]{6}_amd64_[0-9]+\.deb$'
qq_version_pattern='^ARG QQ_VERSION=[0-9]+\.[0-9]+\.[0-9]+$'

patterns=(
  "$dotnet_pattern"
  "$easybot_pattern"
  "$chrome_pattern"
  "$napcat_docker_pattern"
  "$napcat_pattern"
  "$qq_url_pattern"
  "$qq_version_pattern"
)
labels=(
  '.NET image'
  'EasyBot commit'
  'Chrome version'
  'NapCat-Docker commit'
  'NapCat version'
  'QQ deb URL'
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
  "ARG QQ_DEB_URL=${qq_deb_url}"
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
  -e "s#${qq_url_pattern}#${lines[5]}#" \
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
