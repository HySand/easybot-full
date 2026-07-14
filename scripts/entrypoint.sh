#!/usr/bin/env bash

set -uo pipefail

runtime_dir=/run/easybot-napcat
napcat_pid=''
easybot_pid=''
stopping=false

log() {
  printf '[easybot-napcat] %s\n' "$*"
}

is_running() {
  local pid=${1:-}
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

stop_children() {
  if [[ "$stopping" == true ]]; then
    return
  fi
  stopping=true

  for pid in "$napcat_pid" "$easybot_pid"; do
    if is_running "$pid"; then
      kill -TERM "$pid" 2>/dev/null || true
    fi
  done
}

wait_for_children() {
  local pid
  for pid in "$napcat_pid" "$easybot_pid"; do
    if [[ -n "$pid" ]]; then
      wait "$pid" 2>/dev/null || true
    fi
  done
}

# Invoked indirectly by the TERM/INT trap.
# shellcheck disable=SC2329
handle_signal() {
  log 'received stop signal; stopping EasyBot and NapCat'
  trap - TERM INT
  stop_children
  wait_for_children
  exit 143
}

trap handle_signal TERM INT

rm -rf "$runtime_dir"
mkdir -p "$runtime_dir"

log 'starting NapCat'
(
  cd /app || exit 1
  exec /bin/bash /app/entrypoint.sh
) &
napcat_pid=$!
printf '%s\n' "$napcat_pid" > "$runtime_dir/napcat.pid"

log 'starting EasyBot'
(
  cd /opt/easybot || exit 1
  exec ./EasyBot
) &
easybot_pid=$!
printf '%s\n' "$easybot_pid" > "$runtime_dir/easybot.pid"

wait -n "$napcat_pid" "$easybot_pid"
exit_status=$?

trap - TERM INT
if is_running "$napcat_pid"; then
  log 'EasyBot exited; stopping NapCat'
else
  log 'NapCat exited; stopping EasyBot'
fi
stop_children
wait_for_children
rm -rf "$runtime_dir"

# A service exiting cleanly is still a failure for this long-running container.
if [[ "$exit_status" -eq 0 ]]; then
  exit_status=1
fi
exit "$exit_status"
