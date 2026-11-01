#!/bin/sh
# Builds a store bundle, and refuses placeholder links or a missing signing key.
set -e
cd "$(dirname "$0")/.."
for name in APP_LINK SUPPORT_EMAIL TERMS_URL PRIVACY_URL; do
  eval "value=\${$name:-}"
  case "$value" in
    ''|*example.com*) echo "Set $name to the real value." >&2; exit 1 ;;
  esac
done
[ -f android/key.properties ] || { echo "android/key.properties is missing. See docs/DEPLOYMENT.md." >&2; exit 1; }
[ -f android/app/google-services.json ] || { echo "android/app/google-services.json is missing." >&2; exit 1; }
flutter analyze
flutter test
flutter build appbundle --release \
  --dart-define=APP_LINK="$APP_LINK" --dart-define=SUPPORT_EMAIL="$SUPPORT_EMAIL" \
  --dart-define=TERMS_URL="$TERMS_URL" --dart-define=PRIVACY_URL="$PRIVACY_URL"
