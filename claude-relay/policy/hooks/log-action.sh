#!/usr/bin/env bash
# Hook PostToolUse : journalise chaque action de Claude en JSONL dans le volume de logs,
# secrets masqués, avec rotation par taille. Ne bloque jamais Claude (toujours exit 0).
# Tourne dans le conteneur (GNU sed/stat, flock de util-linux).
set -uo pipefail

LOG_DIR=${RELAY_LOG_DIR:-/var/log/claude-relay}
LOG="$LOG_DIR/actions.jsonl"
MAX_BYTES=${RELAY_LOG_MAX_BYTES:-5242880} # 5 Mo par fichier
KEEP=${RELAY_LOG_KEEP:-5}                 # actions.jsonl.1 … .5

# Masquage, fait dans jq sur les chaînes et les clés (le JSON reste valide) : jetons
# connus (Anthropic, GitHub, Slack, AWS, Telegram, JWT/Home Assistant, Bearer/Basic,
# clés privées), paires clé=valeur sensibles, et valeurs des clés d'objet sensibles.
# shellcheck disable=SC2016  # programme jq, pas d'expansion shell voulue
JQ_MASK='
  def sensitive: test("(?i)(pass(wd|word)?|pwd|secret|token|api[_-]?key|apikey|authorization|cookie|credential)");
  def mask:
    gsub("-----BEGIN[^-]*PRIVATE KEY-----[\\s\\S]*?-----END[^-]*PRIVATE KEY-----"; "***private-key***")
    | gsub("sk-ant-[A-Za-z0-9_-]+"; "sk-ant-***")
    | gsub("(?<p>gh[pousr]|github_pat)_[A-Za-z0-9_]{10,}"; "\(.p)_***")
    | gsub("xox[abposr]-[A-Za-z0-9-]+"; "xox*-***")
    | gsub("AKIA[0-9A-Z]{16}"; "AKIA***")
    | gsub("[0-9]{8,10}:[A-Za-z0-9_-]{35}"; "***telegram-bot-token***")
    | gsub("eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]+"; "***jwt***")
    | gsub("(?<s>[Bb]earer|[Bb]asic) +[A-Za-z0-9._~+/=-]{8,}"; "\(.s) ***")
    | gsub("(?i)(?<k>(pass(wd|word)?|pwd|secret|token|api[_-]?key|apikey|authorization|cookie)[\"'"'"']?\\s*[:=]\\s*[\"'"'"']?)[^\\s\"'"'"',&;]+"; "\(.k)***");
  def scrub:
    walk(if type == "object" then with_entries(if (.key | sensitive) and (.value | type) == "string" then .value = "***" else . end)
         elif type == "string" then mask else . end);
'

rotate() {
  local i
  rm -f "$LOG.$KEEP"
  for ((i = KEEP - 1; i >= 1; i--)); do
    [ -f "$LOG.$i" ] && mv -f "$LOG.$i" "$LOG.$((i + 1))"
  done
  mv -f "$LOG" "$LOG.1"
}

main() {
  local input line size
  input=$(cat)
  line=$(jq -c --arg ts "$(date -u +%FT%TZ)" "$JQ_MASK"'{
      ts: $ts,
      session: .session_id,
      event: .hook_event_name,
      tool: .tool_name,
      cwd: .cwd,
      mode: .permission_mode,
      input: ((.tool_input // {}) | scrub | tostring | .[0:4000]),
      response: ((.tool_response // "") | scrub | tostring | .[0:2000])
    }' <<<"$input") || return 0

  mkdir -p "$LOG_DIR" || return 0
  exec 9>>"$LOG_DIR/.lock" || return 0
  flock -w 5 9 || true
  size=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
  if [ "$size" -ge "$MAX_BYTES" ]; then
    rotate
  fi
  printf '%s\n' "$line" >>"$LOG"
}

main || true
exit 0
