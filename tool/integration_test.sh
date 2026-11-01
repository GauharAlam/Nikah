#!/bin/sh
# Runs integration_test on a booted Android emulator against the local Firebase
# emulators. Needs JAVA_HOME set (see docs/TESTING.md).
set -e
cd "$(dirname "$0")/.."
(cd functions && npm run build)
cd functions
exec npx firebase emulators:exec --project demo-nikah --only auth,firestore,storage,functions \
  "cd .. && flutter test --dart-define=BACKEND=emulator $*"
