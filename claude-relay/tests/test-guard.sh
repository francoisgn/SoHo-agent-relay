#!/usr/bin/env bash
# Rejoue tests/guard-cases.txt, puis tests/guard-cases.local s'il existe (cas propres à une installation, non
# versionnés), contre policy/hooks/guard-bash.sh (jq requis).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
guard="$here/../policy/hooks/guard-bash.sh"
cases=("$here/guard-cases.txt")
[ -f "$here/guard-cases.local" ] && cases+=("$here/guard-cases.local")

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then g=$'\e[32m'; r=$'\e[31m'; n=$'\e[0m'; else g=; r=; n=; fi

# Noms de secrets que relay-loop exporterait (le hook lit cette liste).
export RELAY_SECRET_NAMES="QBT_PASSWORD UNIFI_API_KEY"

fail=0 total=0
while IFS=$'\t' read -r expected command; do
  case "$expected" in ''|'#'*) continue ;; esac
  total=$((total + 1))
  out=$(jq -cn --arg c "$command" '{tool_input:{command:$c}}' | bash "$guard")
  got=allow
  [ -n "$out" ] && got=deny
  if [ "$got" = "$expected" ]; then
    printf '%sok%s   %-5s %s\n' "$g" "$n" "$got" "$command"
  else
    printf '%sko%s   %-5s (expected %s) %s\n' "$r" "$n" "$got" "$expected" "$command"
    fail=$((fail + 1))
  fi
done < <(cat "${cases[@]}")

if [ "$fail" -gt 0 ]; then
  printf '%sko%s   %d/%d guard cases failed\n' "$r" "$n" "$fail" "$total"
  exit 1
fi
printf '%sok%s   %d guard cases passed\n' "$g" "$n" "$total"
