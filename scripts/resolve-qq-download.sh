#!/usr/bin/env bash

set -euo pipefail
export LC_ALL=C

usage() {
  printf 'Usage: %s <linux-config-url> [expected-version] [expected-url-sha256]\n' "$0" >&2
}

die() {
  printf 'resolve-qq-download: %s\n' "$*" >&2
  exit 1
}

if [[ "$#" -lt 1 || "$#" -gt 3 ]]; then
  usage
  exit 2
fi

config_url=$1
expected_version=${2:-}
expected_url_sha256=${3:-}

[[ "$config_url" == 'https://cdn-go.cn/qq-web/im.qq.com_new/latest/rainbow/linuxConfig.js' ]] \
  || die 'invalid official Linux QQ config URL'
[[ -z "$expected_version" || "$expected_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || die 'invalid expected QQ version'
[[ -z "$expected_url_sha256" || "$expected_url_sha256" =~ ^[0-9a-f]{64}$ ]] \
  || die 'invalid expected QQ URL SHA-256'

config=$(curl --fail --silent --show-error --location \
  --retry 5 --retry-all-errors "$config_url")
config_json=$(sed -nE \
  's/^[[:space:]]*;\(function\(\)\{var params= (\{.*\});[[:space:]]*$/\1/p' \
  <<< "$config")
[[ -n "$config_json" ]] || die 'unable to parse official Linux QQ config'

version=$(jq -er \
  '.version | strings | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))' \
  <<< "$config_json")
deb_url=$(jq -er '.x64DownloadUrl.deb | strings | select(length > 0)' \
  <<< "$config_json")

[[ "$deb_url" =~ ^https://(qqdl\.gtimg\.cn|dldir1(v6)?\.qq\.com)/qqfile/[A-Za-z0-9._/-]+/QQ_[0-9]+\.[0-9]+\.[0-9]+_[0-9]{6}_amd64_[0-9]+\.deb$ ]] \
  || die 'invalid official QQ amd64 deb URL'
[[ "$deb_url" == *"/QQ_${version}_"* ]] || die 'QQ URL and version do not match'
[[ -z "$expected_version" || "$version" == "$expected_version" ]] \
  || die "official QQ version ${version} does not match locked version ${expected_version}"
url_sha256=$(printf '%s' "$deb_url" | sha256sum | cut -d ' ' -f 1)
[[ -z "$expected_url_sha256" || "$url_sha256" == "$expected_url_sha256" ]] \
  || die 'official QQ download URL does not match its locked SHA-256'

jq -cn --arg version "$version" --arg deb_url "$deb_url" \
  --arg url_sha256 "$url_sha256" \
  '{version: $version, deb_url: $deb_url, url_sha256: $url_sha256}'
