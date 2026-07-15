#!/bin/zsh

set -euo pipefail

source_dir="${0:A:h}"
label="com.codex.lid-awake-30m"
plist="/Library/LaunchDaemons/${label}.plist"
script="/usr/local/libexec/codex-lid-awake-30m.sh"

/bin/launchctl bootout system/"$label" >/dev/null 2>&1 || true
# launchd can briefly retain a just-removed label and reject an immediate
# bootstrap with error 5. Give the system domain time to finish removal.
/bin/sleep 3
/bin/mkdir -p /usr/local/libexec
/bin/cp "$source_dir/codex-lid-awake-30m.sh" "$script"
/bin/cp "$source_dir/com.codex.lid-awake-30m.plist" "$plist"
/usr/sbin/chown root:wheel "$script" "$plist"
/bin/chmod 755 "$script"
/bin/chmod 644 "$plist"
/usr/bin/plutil -lint "$plist"

for attempt in 1 2 3 4 5; do
  if /bin/launchctl bootstrap system "$plist"; then
    break
  fi
  if (( attempt == 5 )); then
    print -u2 -- "Unable to register $label after $attempt attempts"
    exit 1
  fi
  /bin/sleep 2
done

/bin/launchctl kickstart -k system/"$label"
