#!/usr/bin/env bash

set -Eeuo pipefail
export LC_ALL=C

usage() {
  printf 'Usage: %s <url> <output>\n' "$0" >&2
}

die() {
  printf 'download-qq-deb: %s\n' "$*" >&2
  exit 1
}

if [[ "$#" -ne 2 ]]; then
  usage
  exit 2
fi

url=$1
output=$2
[[ "$url" =~ ^https://(qqdl\.gtimg\.cn|dldir1(v6)?\.qq\.com)/qqfile/[A-Za-z0-9._/-]+/QQ_[0-9]+\.[0-9]+\.[0-9]+_[0-9]{6}_amd64_[0-9]+\.deb$ ]] \
  || die 'invalid official QQ amd64 deb URL'

headers=$(mktemp)
probe=$(mktemp)
part=$(mktemp "${output}.part.XXXXXX")
chunk=$(mktemp "${output}.chunk.XXXXXX")
cleanup() {
  rm -f "$headers" "$probe" "$part" "$chunk"
}
trap cleanup EXIT

curl_common=(
  --fail
  --silent
  --show-error
  --location
  --ipv4
  --http1.1
  --retry 3
  --retry-delay 5
  --retry-max-time 90
  --retry-all-errors
  --connect-timeout 30
  --max-time 120
  --speed-limit 1024
  --speed-time 30
  --header 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36'
  --header 'Referer: https://im.qq.com/linuxqq/'
)

printf 'Probing Linux QQ package size: %s\n' "$url"
curl "${curl_common[@]}" \
  --dump-header "$headers" \
  --range 0-0 \
  --output "$probe" \
  "$url" \
  || die 'unable to probe the official QQ package'

probe_size=$(wc -c < "$probe")
[[ "$probe_size" -eq 1 ]] || die "QQ CDN did not honor a one-byte range request (received ${probe_size} bytes)"

total_size=$(sed -nE \
  's#^[^:]+:[[:space:]]*bytes[[:space:]]+0-0/([0-9]+)[[:space:]]*$#\1#Ip' \
  "$headers" | tail -n 1)
if [[ ! "$total_size" =~ ^[0-9]+$ ]]; then
  total_size=$(sed -nE \
    's#^[^:]+:[[:space:]]*([0-9]+)[[:space:]]*$#\1#Ip' \
    "$headers" | tail -n 1)
fi
[[ "$total_size" =~ ^[1-9][0-9]*$ ]] || die 'QQ CDN did not provide a valid package size'

chunk_size=16777216
: > "$part"
offset=0
chunk_number=0
while (( offset < total_size )); do
  end=$((offset + chunk_size - 1))
  if (( end >= total_size )); then
    end=$((total_size - 1))
  fi
  expected_size=$((end - offset + 1))
  chunk_number=$((chunk_number + 1))
  downloaded=false

  for attempt in 1 2 3 4 5; do
    rm -f "$chunk"
    printf 'Downloading QQ chunk %d (%d-%d, attempt %d/5)\n' \
      "$chunk_number" "$offset" "$end" "$attempt"
    if curl "${curl_common[@]}" \
      --range "${offset}-${end}" \
      --output "$chunk" \
      "$url"; then
      actual_size=$(wc -c < "$chunk")
      if [[ "$actual_size" -eq "$expected_size" ]]; then
        cat "$chunk" >> "$part"
        downloaded=true
        break
      fi
      printf 'QQ chunk size mismatch: expected %d, received %d\n' \
        "$expected_size" "$actual_size" >&2
    fi
    sleep 10
  done

  [[ "$downloaded" == true ]] || die "unable to download QQ chunk ${offset}-${end}"
  offset=$((end + 1))
done

actual_total=$(wc -c < "$part")
[[ "$actual_total" -eq "$total_size" ]] || die "QQ package size mismatch: expected ${total_size}, received ${actual_total}"
mv "$part" "$output"
trap - EXIT
rm -f "$headers" "$probe" "$chunk"
printf 'Downloaded Linux QQ package (%d bytes).\n' "$actual_total"
