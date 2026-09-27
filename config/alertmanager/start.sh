#!/bin/sh
set -eu

# Validate before interpolating into YAML; never echo credential values.
fail() { echo "$1" >&2; exit 1; }
token=${TELEGRAM_BOT_TOKEN:-}
chat=${TELEGRAM_CHAT_ID:-}
printf '%s\n' "$token" | grep -Eq '^[0-9]+:[A-Za-z0-9_-]+$' || fail 'Invalid or missing TELEGRAM_BOT_TOKEN'
case "$token" in *[!0-9A-Za-z_:-]*) fail 'Invalid TELEGRAM_BOT_TOKEN';; esac
printf '%s\n' "$chat" | grep -Eq '^-?[0-9]+$' || fail 'Invalid or missing TELEGRAM_CHAT_ID'
case "$chat" in *[!0-9-]*) fail 'Invalid TELEGRAM_CHAT_ID';; esac
[ "$chat" != 0 ] || fail 'Invalid TELEGRAM_CHAT_ID'
umask 077
config=/tmp/alertmanager.yml
cat > "$config" <<EOF
route:
  receiver: telegram
  group_by: [alertname, service]
  group_wait: 5s
  group_interval: 30s
  repeat_interval: 15m
receivers:
  - name: telegram
    telegram_configs:
      - bot_token: '$token'
        chat_id: $chat
        send_resolved: true
        parse_mode: ''
        message: |-
          {{ range .Alerts }}{{ if eq .Status "firing" }}FIRING{{ else }}RESOLVED{{ end }}: {{ .Labels.alertname }}
          {{ if .Labels.severity }}Severity: {{ .Labels.severity }}{{ end }}
          {{ if .Labels.service }}Service: {{ .Labels.service }}{{ end }}
          {{ if .Labels.instance }}Instance: {{ .Labels.instance }}{{ end }}
          {{ if eq .Status "firing" }}{{ if .Annotations.summary }}Summary: {{ .Annotations.summary }}{{ end }}
          {{ if .Annotations.description }}Details: {{ .Annotations.description }}{{ end }}
          {{ if .Annotations.rate }}Measured rate: {{ .Annotations.rate }} requests/s{{ end }}
          {{ else }}The alert condition has cleared.{{ end }}
          Started: {{ .StartsAt }}
          {{ if eq .Status "resolved" }}Ended: {{ .EndsAt }}{{ end }}
          {{ end }}
EOF
# Suppress parser output because malformed configs may contain credentials.
/bin/amtool check-config "$config" >/dev/null 2>&1 || fail 'Alertmanager configuration validation failed'
if [ "${1:-}" = '--check' ]; then
  echo 'Alertmanager configuration valid'
  exit 0
fi
exec /bin/alertmanager --config.file="$config" --storage.path=/alertmanager --cluster.listen-address=
