#!/bin/sh

set -e

[[ -z "$CHECK_DURATION_SECONDS" ]] && CHECK_DURATION_SECONDS='60'
[[ -z "$MYIP_TIMEOUT_SECONDS" ]] && MYIP_TIMEOUT_SECONDS='60'

set -u

get_myip() {
  timeout -t "$MYIP_TIMEOUT_SECONDS" \
    myip -t "${MYIP_TIMEOUT_SECONDS}s" 2>/dev/null
}

get_myip_with_waiting_for_success() {
  local ip
  ip=$(get_myip)
  while [[ -z "$ip" ]]
  do
    ip=$(get_myip)
  done
  echo -n "$ip"
}

notify_slack_that_ip_is_changed() {
  local ip
  ip="$1"
  local message
  message=$(
IP="$ip" python3 <<'EOT'
import json
import os
ip = os.getenv('IP')
icon_emoji = os.getenv('SLACK_ICON_EMOJI', ':globe_with_meridians:')
username = os.getenv('SLACK_USERNAME', 'Home IP Changed')
message = {
    'text': f"`{ip}`",
    'username': username,
    'icon_emoji': icon_emoji,
}
print(json.dumps(message))
EOT
  )
  curl \
    -X POST \
    -H 'Content-type: application/json' \
    --data "$message" \
    "$SLACK_INCOMING_WEBHOOK_URL" >/dev/null 2>&1
}

update_security_group_ip() {
  if [[ -z "$AWS_TARGET_SECURITY_GROUP" ]]
  then
    return
  fi
  ip="$1"
  aws ec2 describe-security-groups --group-names "$AWS_TARGET_SECURITY_GROUP" \
  | jq -r '.SecurityGroups[].IpPermissions[].IpRanges[].CidrIp' \
  | xargs -r -n 1 \
      aws ec2 revoke-security-group-ingress \
        --group-name "$AWS_TARGET_SECURITY_GROUP" \
        --protocol tcp \
        --port 22 \
        --cidr
  aws ec2 authorize-security-group-ingress \
    --group-name "$AWS_TARGET_SECURITY_GROUP" \
    --protocol tcp \
    --port 22 \
    --cidr "$ip"/32
}

handler_ip_changed() {
  local ip
  ip="$1"
  set +e
    update_security_group_ip "$ip"
    notify_slack_that_ip_is_changed "$ip"
  set -e
}

main() {
  local previous_ip=''
  local current_ip=''
  while true
  do
    current_ip=$(get_myip_with_waiting_for_success)
    if [[ "$current_ip" != "$previous_ip" ]]
    then
      handler_ip_changed "$current_ip"
      previous_ip="$current_ip"
    fi
    sleep "$CHECK_DURATION_SECONDS"
  done
}

main
