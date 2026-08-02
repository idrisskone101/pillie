#!/bin/sh

# ci_pre_xcodebuild.sh
# Runs automatically in Xcode Cloud before each xcodebuild action.
#
# Forces every target's build number (CURRENT_PROJECT_VERSION) to Xcode Cloud's
# unique, monotonically increasing $CI_BUILD_NUMBER. This guarantees:
#   1. TestFlight never rejects an upload for a duplicate/non-increasing build.
#   2. The app and its 3 extensions (DeviceActivityMonitor, ShieldAction,
#      ShieldConfiguration) all share one build number, which TestFlight
#      requires for an app bundled with extensions.
#
# All target Info.plists already resolve CFBundleVersion from
# $(CURRENT_PROJECT_VERSION), so overriding it in the project file is enough.

set -e

if [ -z "$CI_BUILD_NUMBER" ]; then
  echo "CI_BUILD_NUMBER not set; leaving build number unchanged."
  exit 0
fi

# Xcode Cloud also invokes this hook before test-without-building actions. Those
# actions reuse products from build-for-testing and do not check out the source
# repository, so there is no project file whose build number needs updating.
if [ -z "$CI_PRIMARY_REPOSITORY_PATH" ]; then
  echo "CI_PRIMARY_REPOSITORY_PATH not set; no source checkout to update."
  exit 0
fi

PROJECT="$CI_PRIMARY_REPOSITORY_PATH/Pillie/Pillie.xcodeproj/project.pbxproj"

echo "Setting CURRENT_PROJECT_VERSION to $CI_BUILD_NUMBER"
# macOS sed (Xcode Cloud runners are macOS) requires the empty arg after -i.
sed -i '' -e "s/CURRENT_PROJECT_VERSION = [0-9]\{1,\};/CURRENT_PROJECT_VERSION = $CI_BUILD_NUMBER;/g" "$PROJECT"

echo "Updated build-number entries:"
grep "CURRENT_PROJECT_VERSION" "$PROJECT" | sort -u
