#!/bin/bash
# Signs an unsigned Derin.app for App Store distribution and packs it into an .ipa.
#   ci/sign_app.sh <Derin.app> <signing dir from asc_signing.py> <output.ipa>
# Needs TEAM_ID, SIGN_IDENTITY (SHA-1), SIGN_KEYCHAIN, SCREEN_TIME and BUNDLE_PREFIX.
# The designated requirement is written out explicitly (team OU instead of the certificate's
# common name) so it can't be broken by non-ASCII letters in the account holder's name.
set -euo pipefail
APP=$1 SIGNING=$2 IPA=$3

sign_bundle() {
  local bundle=$1 id ent
  id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$bundle/Info.plist")
  cp "$SIGNING/$id.mobileprovision" "$bundle/embedded.mobileprovision"

  ent="$SIGNING/$id.entitlements"
  plutil -create xml1 "$ent"
  plutil -insert application-identifier -string "$TEAM_ID.$id" "$ent"
  plutil -insert com\\.apple\\.developer\\.team-identifier -string "$TEAM_ID" "$ent"
  plutil -insert get-task-allow -bool NO "$ent"
  plutil -insert beta-reports-active -bool YES "$ent"
  # Accounts: Sign in with Apple, on the app only.
  if [ "$id" = "$BUNDLE_PREFIX.derin" ]; then
    plutil -insert com\\.apple\\.developer\\.applesignin -array "$ent"
    plutil -insert com\\.apple\\.developer\\.applesignin.0 -string Default "$ent"
  fi
  # The app and the share extension hand over shared music lists through a Keychain group.
  if [ "$id" = "$BUNDLE_PREFIX.derin" ] || [ "$id" = "$BUNDLE_PREFIX.derin.share" ]; then
    plutil -insert keychain-access-groups -array "$ent"
    plutil -insert keychain-access-groups.0 -string "$TEAM_ID.$id" "$ent"
    plutil -insert keychain-access-groups.1 -string "$TEAM_ID.$BUNDLE_PREFIX.derin.shared" "$ent"
  fi
  # The Live Activity widget and the share extension need neither Family Controls nor the App Group.
  if [ "$SCREEN_TIME" = "YES" ] && [ "$id" != "$BUNDLE_PREFIX.derin.live-activity" ] && [ "$id" != "$BUNDLE_PREFIX.derin.share" ]; then
    plutil -insert com\\.apple\\.developer\\.family-controls -bool YES "$ent"
    plutil -insert com\\.apple\\.security\\.application-groups -array "$ent"
    plutil -insert com\\.apple\\.security\\.application-groups.0 -string "group.$BUNDLE_PREFIX.derin" "$ent"
  fi

  codesign --force --sign "$SIGN_IDENTITY" --keychain "$SIGN_KEYCHAIN" --entitlements "$ent" \
    --generate-entitlement-der --timestamp=none \
    -r="designated => anchor apple generic and identifier \"$id\" and certificate leaf[subject.OU] = \"$TEAM_ID\" and certificate 1[field.1.2.840.113635.100.6.2.1] exists" \
    "$bundle"
  echo "Signed $id"
}

# Inside out: embedded frameworks, then extensions, then the app itself.
for fw in "$APP"/Frameworks/* "$APP"/PlugIns/*.appex/Frameworks/*; do
  [ -e "$fw" ] && codesign --force --sign "$SIGN_IDENTITY" --keychain "$SIGN_KEYCHAIN" --timestamp=none "$fw"
done
for ext in "$APP"/PlugIns/*.appex; do
  [ -d "$ext" ] && sign_bundle "$ext"
done
sign_bundle "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

WORK=$(mktemp -d)
mkdir "$WORK/Payload"
cp -R "$APP" "$WORK/Payload/"
(cd "$WORK" && zip -qry "$IPA" Payload)
echo "Packed $IPA"
