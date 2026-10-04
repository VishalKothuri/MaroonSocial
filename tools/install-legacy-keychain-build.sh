#!/bin/zsh
# Build the current app for a simulator whose signed-in account predates the
# project's DEVELOPMENT_TEAM (today: the iPhone 17 Pro Max, owner account) and
# install it WITHOUT losing that account.
#
# Why: the credential on that simulator lives in keychain access group
# FAKETEAMID.app.maroonsocial.MaroonSocial. Normal builds get
# 259BRQX9UQ.app.maroonsocial.MaroonSocial, cannot read the item, show onboarding
# and reset Documents/social-cache.json (AppStore.swift, "state = LocalState()").
# Neither DEVELOPMENT_TEAM="" nor CODE_SIGN_STYLE=Manual changes that prefix; an
# explicit entitlements file does. Email recovery is paused, so an unreadable
# device credential is a lost account. Simulator only.
set -euo pipefail
cd "$(dirname "$0")/.."
UDID="${1:-88F79EB0-5B16-42A0-B3C2-5A3408CF4D52}"
DERIVED=build/LegacyKeychain
APP_ID=app.maroonsocial.MaroonSocial
echo "Keychain groups holding $APP_ID items on $UDID (read-only):"
sqlite3 ~/Library/Developer/CoreSimulator/Devices/"$UDID"/data/Library/Keychains/keychain-2-debug.db \
  "select agrp, datetime(cdat+978307200,'unixepoch') from genp where agrp like '%maroonsocial%';" || true
xcodebuild build -project MaroonSocial.xcodeproj -scheme MaroonSocial \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" \
  CODE_SIGN_ENTITLEMENTS="$PWD/tools/fixtures/legacy-keychain.entitlements" > build/legacy-keychain-build.log 2>&1 \
  || { echo "Build failed; see build/legacy-keychain-build.log" >&2; exit 1; }
XCENT="$DERIVED/Build/Intermediates.noindex/MaroonSocial.build/Debug-iphonesimulator/MaroonSocial.build/MaroonSocial.app-Simulated.xcent"
grep -q "FAKETEAMID.app.maroonsocial.MaroonSocial" "$XCENT" \
  || { echo "Simulated entitlements do not carry the legacy identifier; not installing." >&2; exit 1; }
xcrun simctl terminate "$UDID" "$APP_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-iphonesimulator/MaroonSocial.app"
xcrun simctl launch "$UDID" "$APP_ID"
echo "Installed. If onboarding appears anyway, stop the app and set onboarded/adult to true in"
echo "\$(xcrun simctl get_app_container $UDID $APP_ID data)/Documents/social-cache.json before relaunching."
