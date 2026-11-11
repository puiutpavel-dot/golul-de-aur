#!/bin/bash
# Arhiva Release + export semnat in cloud (certificatul de distributie il gestioneaza Apple)
# + urcare in App Store Connect / TestFlight. Are nevoie doar de cheia App Store Connect API
# (rol Admin) din secretele GitHub. Aceeasi metoda ca in repo-ul whist-ios.
set -e
OUT_DIR="${OUT_DIR:-$PWD/ci-out}"; mkdir -p "$OUT_DIR"
: "${ASC_KEY_ID:?lipseste secretul ASC_KEY_ID}" "${ASC_ISSUER_ID:?lipseste secretul ASC_ISSUER_ID}"
: "${TEAM_ID:?lipseste TEAM_ID}" "${BUILD_NUMBER:?lipseste BUILD_NUMBER}" "${BUNDLE_ID:?lipseste BUNDLE_ID}"
KEY="$OUT_DIR/AuthKey_$ASC_KEY_ID.p8"
printf '%s\n' "$ASC_PRIVATE_KEY" > "$KEY"
AUTH=(-allowProvisioningUpdates -authenticationKeyPath "$KEY" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
ARCHIVE="$OUT_DIR/GolulDeAur.xcarchive"
echo "Echipa $TEAM_ID, build $BUILD_NUMBER"

set -o pipefail
archive() {
  rm -rf "$ARCHIVE"
  xcodebuild -project GolulDeAur.xcodeproj -scheme GolulDeAur -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" DEVELOPMENT_TEAM="$TEAM_ID" "$@" \
    archive 2>&1 | tee "$OUT_DIR/archive.log" | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true
  grep -q "ARCHIVE SUCCEEDED" "$OUT_DIR/archive.log"
}
# Intai cu semnatura ad-hoc; daca nu merge, nesemnat + semnatura ad-hoc pusa cu codesign.
if ! archive CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- PROVISIONING_PROFILE_SPECIFIER=; then
  echo "Semnarea ad-hoc n-a mers; arhivez nesemnat:"; grep -E "error:" "$OUT_DIR/archive.log" | sort -u | head -20
  archive CODE_SIGNING_ALLOWED=NO || { echo "Arhivarea a esuat"; grep -E "error:" "$OUT_DIR/archive.log" | sort -u | head -50; exit 1; }
  APP="$ARCHIVE/Products/Applications/GolulDeAur.app"
  ENT="$OUT_DIR/ent.plist"
  /usr/libexec/PlistBuddy -c "Add :application-identifier string $TEAM_ID.$BUNDLE_ID" "$ENT"
  /usr/libexec/PlistBuddy -c "Add :com.apple.developer.team-identifier string $TEAM_ID" "$ENT"
  codesign --force --sign - --entitlements "$ENT" --generate-entitlement-der "$APP"
fi

cat > "$OUT_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>upload</string>
  <key>signingStyle</key><string>automatic</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>uploadSymbols</key><true/>
  <key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT_DIR/export" \
  -exportOptionsPlist "$OUT_DIR/ExportOptions.plist" "${AUTH[@]}" 2>&1 | tee "$OUT_DIR/export.log" | tail -40
rm -f "$KEY"
grep -qE "EXPORT SUCCEEDED|Upload succeeded|Uploaded" "$OUT_DIR/export.log" || { echo "Exportul / urcarea a esuat"; exit 1; }
echo "Gata: build $BUILD_NUMBER urcat in App Store Connect (apare in TestFlight dupa procesare)."
