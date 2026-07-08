#!/usr/bin/env bash
set -euo pipefail

# Re-badges the single built iOS IPA (raichu donor) into one landscape's
# release artifact — the iOS half of the build-once/stamp-per-landscape CD
# model (Android: scripts/ci/stamp-android.sh). The compiled app is
# landscape-agnostic (bundle-id-as-marker); per-landscape content is packaging
# only: bundle ids (app + widget), display name, icon pointer (the donor's
# Assets.car carries every AppIcon-* set via
# ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS), App Group, provisioning
# profiles, and CFBundleVersion. Everything is patched with PlistBuddy and
# re-signed inner→outer with codesign.
#
# Usage:
#   stamp-ios.sh <in.ipa> <landscape> <build-number> <out.ipa>
#
# Expects (prepared by cd-ios.sh):
#   - the landscape's App Store profiles fetched to the standard profile dirs
#     (app-store-connect fetch-signing-files) and doctor-ios.sh-verified;
#   - the Apple Distribution certificate in the keychain (keychain
#     add-certificates), matching those profiles.

IN=$1 LANDSCAPE=$2 BUILD_NUMBER=$3 OUT=$4

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LPSM="$ROOT/lpsm.yaml"
P=$(yq '.platform' "$LPSM")
S=$(yq '.service' "$LPSM")
NEW_ID="cloud.atomi.$LANDSCAPE.$P.$S.app"
WIDGET_ID="$NEW_ID.widget"
GROUP="group.$NEW_ID"

# Display name comes from the flavor's xcconfig — the file that defines it for
# real per-flavor builds — so the stamp can never drift from Xcode's output.
NEW_NAME=$(sed -n 's/^BUNDLE_DISPLAY_NAME=\(.*\)$/\1/p' "$ROOT/ios/Flutter/${LANDSCAPE}Release.xcconfig")
[ -n "$NEW_NAME" ] || {
  echo "stamp-ios: no BUNDLE_DISPLAY_NAME in ${LANDSCAPE}Release.xcconfig" >&2
  exit 1
}

PROFILE_DIRS=(
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
  "$HOME/Library/MobileDevice/Provisioning Profiles"
)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

unzip -qq "$IN" -d "$WORK"
APP="$WORK/Payload/Runner.app"
APPEX="$APP/PlugIns/NeonWidgetExtension.appex"
[ -d "$APP" ] && [ -d "$APPEX" ] || {
  echo "stamp-ios: unexpected IPA layout in $IN" >&2
  exit 1
}

pb() { /usr/libexec/PlistBuddy -c "$1" "$2"; }
pbq() { /usr/libexec/PlistBuddy -c "$1" "$2" 2>/dev/null || true; }

# --- locate the landscape's profiles (by their baked application-identifier) --
# find_profile <bundle-id> <dest>: also emits the profile's Entitlements dict
# to <dest>.entitlements — used verbatim for codesign, so the signature always
# matches what Apple put in the profile (app group, beta-reports-active, team).
find_profile() {
  local want=$1 dest=$2 plist appid profile
  plist=$(mktemp)
  for dir in "${PROFILE_DIRS[@]}"; do
    for profile in "$dir"/*.mobileprovision; do
      [ -e "$profile" ] || continue
      security cms -D -i "$profile" >"$plist" 2>/dev/null || continue
      appid=$(pbq "Print :Entitlements:application-identifier" "$plist")
      if [ "${appid#*.}" = "$want" ]; then
        cp "$profile" "$dest"
        pb "Print :Entitlements" "$plist" >/dev/null # sanity: dict exists
        plutil -extract Entitlements xml1 -o "$dest.entitlements" "$plist"
        rm -f "$plist"
        return 0
      fi
    done
  done
  rm -f "$plist"
  echo "stamp-ios: no provisioning profile for $want — did cd-ios.sh fetch-signing-files for $LANDSCAPE?" >&2
  return 1
}

find_profile "$NEW_ID" "$WORK/app.mobileprovision"
find_profile "$WIDGET_ID" "$WORK/widget.mobileprovision"

# --- patch the app's Info.plist -----------------------------------------------
INFO="$APP/Info.plist"
pb "Set :CFBundleIdentifier $NEW_ID" "$INFO"
pb "Set :CFBundleName $NEW_NAME" "$INFO"
pbq "Set :CFBundleDisplayName $NEW_NAME" "$INFO"
pb "Set :CFBundleVersion $BUILD_NUMBER" "$INFO"
pb "Set :NeonAppGroup $GROUP" "$INFO"
# Re-point every icon reference from the donor's set to this landscape's
# (Assets.car carries all sets — see raichuRelease.xcconfig).
OLD_PREFIX=$(pbq "Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName" "$INFO" | sed 's/AppIcon-//')
for keypath in \
  ":CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName" \
  ":CFBundleIcons~ipad:CFBundlePrimaryIcon:CFBundleIconName" \
  ":CFBundleIconName"; do
  cur=$(pbq "Print $keypath" "$INFO")
  [ -n "$cur" ] && pb "Set $keypath AppIcon-$LANDSCAPE" "$INFO"
done
# CFBundleIconFiles entries keep the donor prefix (e.g. AppIcon-raichu60x60).
for icons in ":CFBundleIcons" ":CFBundleIcons~ipad"; do
  i=0
  while :; do
    cur=$(pbq "Print $icons:CFBundlePrimaryIcon:CFBundleIconFiles:$i" "$INFO")
    [ -n "$cur" ] || break
    pb "Set $icons:CFBundlePrimaryIcon:CFBundleIconFiles:$i ${cur/AppIcon-$OLD_PREFIX/AppIcon-$LANDSCAPE}" "$INFO"
    i=$((i + 1))
  done
done

# --- patch the widget's Info.plist ---------------------------------------------
WINFO="$APPEX/Info.plist"
pb "Set :CFBundleIdentifier $WIDGET_ID" "$WINFO"
pb "Set :CFBundleVersion $BUILD_NUMBER" "$WINFO"
pb "Set :NeonAppGroup $GROUP" "$WINFO"

# --- embed profiles + re-sign inner→outer --------------------------------------
# Frameworks are untouched (their signatures stay valid); re-signing the outer
# bundles re-seals the resource envelope that covers them.
cp "$WORK/app.mobileprovision" "$APP/embedded.mobileprovision"
cp "$WORK/widget.mobileprovision" "$APPEX/embedded.mobileprovision"

IDENTITY=$(security find-identity -v -p codesigning | sed -n 's/.*\([0-9A-F]\{40\}\) "Apple Distribution.*/\1/p' | head -1)
[ -n "$IDENTITY" ] || {
  echo "stamp-ios: no Apple Distribution identity in the keychain" >&2
  exit 1
}

codesign --force --sign "$IDENTITY" \
  --entitlements "$WORK/widget.mobileprovision.entitlements" "$APPEX"
codesign --force --sign "$IDENTITY" \
  --entitlements "$WORK/app.mobileprovision.entitlements" "$APP"

# --- repack (keep Symbols/ SwiftSupport/ etc. from the donor export) ----------
rm -f "$OUT"
OUT_ABS=$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")
(cd "$WORK" && zip -qry "$OUT_ABS" . -x "*.mobileprovision*" -x "app.mobileprovision.entitlements" -x "widget.mobileprovision.entitlements")

# --- doctor --------------------------------------------------------------------
# Assert every stamped field before this artifact goes anywhere near TestFlight.
codesign --verify --deep --strict "$APP"
for check in \
  "CFBundleIdentifier=$NEW_ID=$INFO" \
  "CFBundleVersion=$BUILD_NUMBER=$INFO" \
  "NeonAppGroup=$GROUP=$INFO" \
  "CFBundleIdentifier=$WIDGET_ID=$WINFO" \
  "NeonAppGroup=$GROUP=$WINFO"; do
  key=${check%%=*}
  rest=${check#*=}
  want=${rest%%=*}
  plist=${rest#*=}
  got=$(pb "Print :$key" "$plist")
  [ "$got" = "$want" ] || {
    echo "stamp-ios doctor: $plist $key = '$got', want '$want'" >&2
    exit 1
  }
done
codesign -d --entitlements :- "$APP" 2>/dev/null | grep -qF "$GROUP" || {
  echo "stamp-ios doctor: app signature lacks App Group $GROUP" >&2
  exit 1
}
codesign -d --entitlements :- "$APPEX" 2>/dev/null | grep -qF "$GROUP" || {
  echo "stamp-ios doctor: widget signature lacks App Group $GROUP" >&2
  exit 1
}

echo "stamp-ios: $LANDSCAPE ok — $NEW_ID build=$BUILD_NUMBER name='$NEW_NAME'"
