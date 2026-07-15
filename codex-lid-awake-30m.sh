#!/bin/zsh

set -u

readonly HOLD_SECONDS=1800
readonly POLL_SECONDS=2
readonly LABEL="com.codex.lid-awake-30m"

log() {
  /usr/bin/logger -t "$LABEL" -- "$1"
}

set_sleep_disabled() {
  /usr/bin/pmset -a disablesleep "$1"
}

read_lid_state() {
  local state

  state=$(/usr/sbin/ioreg -r -k AppleClamshellState -d 4 2>/dev/null | \
    /usr/bin/awk '/"AppleClamshellState"/ { print $NF; exit }')

  case "$state" in
    Yes) print -r -- "closed" ;;
    No)  print -r -- "open" ;;
    *)   print -r -- "unknown" ;;
  esac
}

read_codex_state() {
  local assertions line

  if ! assertions=$(/usr/bin/pmset -g assertions 2>/dev/null); then
    print -r -- "unknown"
    return
  fi

  while IFS= read -r line; do
    if [[ ("$line" == *"(ChatGPT):"* || "$line" == *"(Codex):"*) &&
          "$line" == *'NoIdleSleepAssertion named: "Electron"'* ]]; then
      print -r -- "active"
      return
    fi
  done <<< "$assertions"

  print -r -- "inactive"
}

read_sleep_disabled() {
  local value

  value=$(/usr/bin/pmset -g live 2>/dev/null | \
    /usr/bin/awk '/SleepDisabled/ { print $2; exit }')
  case "$value" in
    0|1) print -r -- "$value" ;;
    *)   print -r -- "-1" ;;
  esac
}

cleanup() {
  set_sleep_disabled 0 >/dev/null 2>&1 || true
}

trap cleanup TERM INT

# Read the existing value without creating a restart gap. The first activity
# check below reconciles it to 1 for an active task or 0 for normal operation.
sleep_disabled=$(read_sleep_disabled)
closed_since=-1
timed_out=0
last_codex_state="unknown"

while true; do
  codex_state=$(read_codex_state)

  case "$codex_state" in
    active)
      lid_state=$(read_lid_state)
      if [[ "$last_codex_state" != "active" ]]; then
        log "Codex task active; lid-close protection armed"
      fi

      case "$lid_state" in
        open)
          closed_since=-1
          timed_out=0
          if (( sleep_disabled != 1 )) && set_sleep_disabled 1; then
            sleep_disabled=1
          fi
          ;;
        closed)
          if (( closed_since < 0 )); then
            closed_since=$SECONDS
            timed_out=0
            log "Lid closed during a Codex task; keeping awake for up to 30 minutes"
          fi

          if (( timed_out == 0 && SECONDS - closed_since >= HOLD_SECONDS )); then
            if set_sleep_disabled 0; then
              sleep_disabled=0
              timed_out=1
              log "30-minute lid-closed limit reached; sleep is allowed"
            fi
          elif (( timed_out == 0 && sleep_disabled != 1 )) && set_sleep_disabled 1; then
            sleep_disabled=1
          fi
          ;;
        unknown)
          # Preserve the current timer and override on a transient read error.
          ;;
      esac
      ;;
    inactive)
      if (( sleep_disabled != 0 )) && set_sleep_disabled 0; then
        sleep_disabled=0
      fi
      if [[ "$last_codex_state" == "active" ]]; then
        log "No active Codex task; normal lid sleep restored"
      fi
      closed_since=-1
      timed_out=0
      ;;
    unknown)
      # Preserve current state on a transient pmset read error.
      ;;
  esac

  last_codex_state="$codex_state"
  /bin/sleep "$POLL_SECONDS"
done
