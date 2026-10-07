#!/usr/bin/env bash
# Runs on the EC2 instance (piped over SSH by the deploy workflow).
# Unpacks the uploaded release, points "current" at it and restarts the app.
set -euo pipefail

APP_DIR=/var/www/mymy
RELEASE_DIR="$APP_DIR/releases/$SHA"
ARCHIVE="/tmp/release-$SHA.tar.gz"

mkdir -p "$RELEASE_DIR"
tar -xzf "$ARCHIVE" -C "$RELEASE_DIR"
rm -f "$ARCHIVE"

ln -sfn "$RELEASE_DIR" "$APP_DIR/current"
sudo systemctl restart mymy

# Fail the deploy if the app does not come back up.
for attempt in $(seq 1 15); do
  if curl -fsS -o /dev/null http://127.0.0.1:3000; then
    echo "Deployed $SHA"
    # Keep the 5 most recent releases.
    ls -1dt "$APP_DIR"/releases/* | tail -n +6 | xargs -r rm -rf
    exit 0
  fi
  sleep 2
done

echo "App did not respond on port 3000 after restart" >&2
sudo journalctl -u mymy -n 50 --no-pager >&2
exit 1
