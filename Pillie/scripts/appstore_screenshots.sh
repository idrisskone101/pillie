#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ASC_APP_ID="${ASC_APP_ID:-6759352439}"
ASC_VERSION_ID="${ASC_VERSION_ID:-d5695869-040a-47e6-95ea-cdd7c103a5ef}"
ASC_LOCALIZATION_ID="${ASC_LOCALIZATION_ID:-d8d88bb6-096d-46c0-b55d-5c997ca466b3}"
BUNDLE_ID="${BUNDLE_ID:-com.idrisskone.pillie}"

DISPLAY_TYPE="${DISPLAY_TYPE:-IPHONE_69}"
FRAME_DEVICE="${FRAME_DEVICE:-iphone-air}"
SIM_NAME="${SIM_NAME:-PillieShots-iPhone17ProMax}"
SIM_DEVICE_TYPE="${SIM_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max}"
SIM_RUNTIME="${SIM_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-2}"

PROJECT_PATH="${PROJECT_PATH:-${REPO_ROOT}/Pillie.xcodeproj}"
SCHEME="${SCHEME:-Pillie}"
PLAN_PATH="${PLAN_PATH:-${REPO_ROOT}/.asc/screenshots.json}"
RAW_DIR="${RAW_DIR:-${REPO_ROOT}/screenshots/raw}"
FRAMED_DIR="${FRAMED_DIR:-${REPO_ROOT}/screenshots/framed}"
REVIEW_DIR="${REVIEW_DIR:-${REPO_ROOT}/screenshots/review}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-${REPO_ROOT}/build/appstore-screenshots-derived-data}"

APP_DISPLAY_TYPE="APP_${DISPLAY_TYPE#APP_}"

SCREENSHOT_NAMES=(
  "01_today_overview"
  "02_today_taken"
  "03_calendar_history"
  "04_settings_overview"
  "05_settings_edit_schedule"
)

log() {
  printf '[appstore-screenshots] %s\n' "$*"
}

die() {
  printf '[appstore-screenshots] ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ./scripts/appstore_screenshots.sh preflight
  ./scripts/appstore_screenshots.sh capture
  ./scripts/appstore_screenshots.sh frame
  ./scripts/appstore_screenshots.sh upload
  ./scripts/appstore_screenshots.sh all
EOF
}

cd "${REPO_ROOT}"

add_python_user_bin_to_path() {
  local user_base
  user_base="$(python3 -m site --user-base 2>/dev/null || true)"
  if [[ -n "${user_base}" ]]; then
    export PATH="${user_base}/bin:${PATH}"
  fi
}

require_command() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || die "Missing required command: ${cmd}"
}

install_axe_if_missing() {
  if command -v axe >/dev/null 2>&1; then
    return
  fi
  require_command brew
  log "Installing axe via Homebrew tap cameroncooke/axe"
  brew tap cameroncooke/axe
  brew install axe
  command -v axe >/dev/null 2>&1 || die "axe install failed; ensure 'cameroncooke/axe' tap is reachable"
}

install_koubou_if_missing_or_wrong_version() {
  add_python_user_bin_to_path
  local current_version
  current_version="$(kou --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
  if [[ "${current_version}" == "0.13.0" ]]; then
    return
  fi
  log "Installing koubou==0.13.0 via pip --user"
  if ! python3 -m pip install --user --upgrade "koubou==0.13.0"; then
    log "Retrying koubou install with --break-system-packages (PEP 668 environment)"
    python3 -m pip install --user --break-system-packages --upgrade "koubou==0.13.0"
  fi
  add_python_user_bin_to_path
  command -v kou >/dev/null 2>&1 || die "koubou install failed; expected 'kou' binary on PATH"
  current_version="$(kou --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
  [[ "${current_version}" == "0.13.0" ]] || die "Expected koubou 0.13.0 but found '${current_version}'"
}

bootstrap_dependencies() {
  require_command asc
  require_command jq
  require_command xcrun
  require_command python3
  require_command xcodebuild
  require_command sips
  install_axe_if_missing
  install_koubou_if_missing_or_wrong_version
  require_command axe
  require_command kou
}

validate_asc_context() {
  log "Validating ASC auth + IDs"
  asc auth status --validate --verbose >/dev/null

  local apps_json versions_json loc_json
  apps_json="$(asc apps list --bundle-id "${BUNDLE_ID}" --output json)"
  echo "${apps_json}" | jq -e --arg app_id "${ASC_APP_ID}" '.data[] | select(.id == $app_id)' >/dev/null \
    || die "App ID ${ASC_APP_ID} not found for bundle ${BUNDLE_ID}"

  versions_json="$(asc versions list --app "${ASC_APP_ID}" --platform IOS --paginate --output json)"
  echo "${versions_json}" | jq -e --arg version_id "${ASC_VERSION_ID}" '.data[] | select(.id == $version_id)' >/dev/null \
    || die "Version ID ${ASC_VERSION_ID} not found under app ${ASC_APP_ID}"

  loc_json="$(asc localizations list --version "${ASC_VERSION_ID}" --locale "en-US" --output json)"
  echo "${loc_json}" | jq -e --arg loc_id "${ASC_LOCALIZATION_ID}" '.data[] | select(.id == $loc_id and .attributes.locale == "en-US")' >/dev/null \
    || die "Localization ID ${ASC_LOCALIZATION_ID} (en-US) not found under version ${ASC_VERSION_ID}"
}

resolve_or_create_simulator() {
  local udid
  udid="$(xcrun simctl list devices --json | jq -r \
    --arg runtime "${SIM_RUNTIME}" \
    --arg name "${SIM_NAME}" \
    '.devices[$runtime][]? | select(.isAvailable == true and .name == $name) | .udid' | head -n1)"

  if [[ -z "${udid}" || "${udid}" == "null" ]]; then
    log "Creating simulator ${SIM_NAME} (${SIM_DEVICE_TYPE}, ${SIM_RUNTIME})" >&2
    udid="$(xcrun simctl create "${SIM_NAME}" "${SIM_DEVICE_TYPE}" "${SIM_RUNTIME}")"
  fi

  [[ -n "${udid}" ]] || die "Unable to resolve or create simulator"
  echo "${udid}"
}

prepare_simulator() {
  local udid="$1"
  log "Preparing simulator ${udid} (shutdown -> erase -> boot)"
  xcrun simctl shutdown "${udid}" >/dev/null 2>&1 || true
  xcrun simctl erase "${udid}"
  xcrun simctl boot "${udid}"
  xcrun simctl bootstatus "${udid}" -b
  xcrun simctl ui "${udid}" appearance light || true
  xcrun simctl status_bar "${udid}" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiMode active \
    --cellularMode active \
    --operatorName "Pillie" || true
}

build_and_install_app() {
  local udid="$1"
  local app_path

  mkdir -p "${DERIVED_DATA_PATH}" "${RAW_DIR}" "${FRAMED_DIR}" "${REVIEW_DIR}"
  [[ -d "${PROJECT_PATH}" ]] || die "Project not found at ${PROJECT_PATH}"

  log "Building ${SCHEME} for simulator ${udid}"
  xcodebuild \
    -project "${PROJECT_PATH}" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -sdk iphonesimulator \
    -destination "id=${udid}" \
    -derivedDataPath "${DERIVED_DATA_PATH}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    clean build >/dev/null

  app_path="${DERIVED_DATA_PATH}/Build/Products/Release-iphonesimulator/${SCHEME}.app"
  [[ -d "${app_path}" ]] || die "Built app not found at ${app_path}"

  log "Installing app to simulator"
  xcrun simctl uninstall "${udid}" "${BUNDLE_ID}" >/dev/null 2>&1 || true
  xcrun simctl install "${udid}" "${app_path}"
}

capture_ui_dump() {
  local udid="$1"
  mkdir -p "${REVIEW_DIR}"
  local stamp dump_path
  stamp="$(date +%Y%m%d_%H%M%S)"
  dump_path="${REVIEW_DIR}/axe_describe_ui_${stamp}.json"
  axe describe-ui --udid "${udid}" >"${dump_path}" 2>&1 || true
  log "UI dump written to ${dump_path}"
}

run_capture() {
  local udid="$1"
  mkdir -p "${RAW_DIR}" "${REVIEW_DIR}"
  rm -f "${RAW_DIR}"/*.png

  log "Seeding onboarding skip (onboardingStep=5)"
  xcrun simctl spawn "${udid}" defaults write "${BUNDLE_ID}" onboardingStep -int 5

  log "Running ASC screenshot capture plan"
  if ! asc screenshots run \
    --plan "${PLAN_PATH}" \
    --udid "${udid}" \
    --bundle-id "${BUNDLE_ID}" \
    --output-dir "${RAW_DIR}" \
    --output json >/dev/null; then
    capture_ui_dump "${udid}"
    die "Screenshot capture failed (no upload attempted). Update labels in ${PLAN_PATH}."
  fi

  local name
  for name in "${SCREENSHOT_NAMES[@]}"; do
    [[ -f "${RAW_DIR}/${name}.png" ]] || die "Missing raw screenshot: ${RAW_DIR}/${name}.png"
  done
  log "Raw screenshots captured: ${#SCREENSHOT_NAMES[@]}"
}

validate_framed_dimensions() {
  local sizes_json allowed_pairs width height pair file
  sizes_json="$(asc screenshots sizes --display-type "${APP_DISPLAY_TYPE}" --output json)"
  allowed_pairs="$(echo "${sizes_json}" | jq -r '.sizes[0].dimensions[] | "\(.width)x\(.height)"')"
  [[ -n "${allowed_pairs}" ]] || die "Could not resolve allowed dimensions for ${APP_DISPLAY_TYPE}"

  for file in "${FRAMED_DIR}"/*.png; do
    width="$(sips -g pixelWidth "${file}" | awk '/pixelWidth/{print $2}')"
    height="$(sips -g pixelHeight "${file}" | awk '/pixelHeight/{print $2}')"
    pair="${width}x${height}"
    if ! grep -qx "${pair}" <<<"${allowed_pairs}"; then
      die "Invalid framed dimensions for ${file}: ${pair} not allowed for ${APP_DISPLAY_TYPE}"
    fi
  done
}

run_frame() {
  mkdir -p "${FRAMED_DIR}"
  rm -f "${FRAMED_DIR}"/*.png

  local name input output
  for name in "${SCREENSHOT_NAMES[@]}"; do
    input="${RAW_DIR}/${name}.png"
    output="${FRAMED_DIR}/${name}.png"
    [[ -f "${input}" ]] || die "Missing raw screenshot for framing: ${input}"
    if ! asc screenshots frame \
      --input "${input}" \
      --device "${FRAME_DEVICE}" \
      --output-path "${output}" \
      --output json >/dev/null; then
      log "Frame failed for ${name}; copying raw screenshot as fallback"
      cp "${input}" "${output}"
    fi
  done

  validate_framed_dimensions
  log "Framing step completed and validated for ${APP_DISPLAY_TYPE}"
}

delete_existing_display_set() {
  local list_json id
  local -a ids=()
  list_json="$(asc screenshots list --version-localization "${ASC_LOCALIZATION_ID}" --output json)"
  while IFS= read -r id; do
    [[ -n "${id}" ]] && ids+=("${id}")
  done < <(echo "${list_json}" | jq -r \
    --arg display_type "${APP_DISPLAY_TYPE}" \
    '.sets[] | select(.set.attributes.screenshotDisplayType == $display_type) | .screenshots[]?.id')

  if [[ "${#ids[@]}" -eq 0 ]]; then
    log "No existing ${APP_DISPLAY_TYPE} screenshots to delete"
    return
  fi

  log "Deleting ${#ids[@]} existing ${APP_DISPLAY_TYPE} screenshots"
  for id in "${ids[@]}"; do
    asc screenshots delete --id "${id}" --confirm >/dev/null
  done
}

verify_upload_results() {
  local list_json count name bad_states
  list_json="$(asc screenshots list --version-localization "${ASC_LOCALIZATION_ID}" --output json)"
  count="$(echo "${list_json}" | jq -r \
    --arg display_type "${APP_DISPLAY_TYPE}" \
    '[.sets[] | select(.set.attributes.screenshotDisplayType == $display_type) | .screenshots[]] | length')"
  [[ "${count}" -eq "${#SCREENSHOT_NAMES[@]}" ]] || die "Expected ${#SCREENSHOT_NAMES[@]} uploaded screenshots, found ${count}"

  bad_states="$(echo "${list_json}" | jq -r \
    --arg display_type "${APP_DISPLAY_TYPE}" \
    '.sets[] | select(.set.attributes.screenshotDisplayType == $display_type) | .screenshots[] | (.attributes.assetDeliveryState.state // "")' \
    | awk 'toupper($0) ~ /(FAIL|ERROR)/')"
  [[ -z "${bad_states}" ]] || die "Upload contains failing states: ${bad_states}"

  for name in "${SCREENSHOT_NAMES[@]}"; do
    echo "${list_json}" | jq -e \
      --arg display_type "${APP_DISPLAY_TYPE}" \
      --arg file_name "${name}.png" \
      '.sets[] | select(.set.attributes.screenshotDisplayType == $display_type) | .screenshots[] | select(.attributes.fileName == $file_name)' >/dev/null \
      || die "Uploaded screenshot filename missing: ${name}.png"
  done

  log "Post-upload verification passed (${count} screenshots in ${APP_DISPLAY_TYPE})"
}

run_upload() {
  local name staging_dir
  for name in "${SCREENSHOT_NAMES[@]}"; do
    [[ -f "${FRAMED_DIR}/${name}.png" ]] || die "Missing framed screenshot: ${FRAMED_DIR}/${name}.png"
  done

  staging_dir="$(mktemp -d)"
  for name in "${SCREENSHOT_NAMES[@]}"; do
    cp "${FRAMED_DIR}/${name}.png" "${staging_dir}/${name}.png"
  done

  delete_existing_display_set
  log "Uploading framed screenshots"
  asc screenshots upload \
    --version-localization "${ASC_LOCALIZATION_ID}" \
    --path "${staging_dir}" \
    --device-type "${DISPLAY_TYPE}" \
    --output json >/dev/null

  rm -rf "${staging_dir}"
  verify_upload_results
}

run_preflight_action() {
  bootstrap_dependencies
  validate_asc_context
  mkdir -p "${RAW_DIR}" "${FRAMED_DIR}" "${REVIEW_DIR}"
  log "Preflight complete"
}

run_capture_action() {
  run_preflight_action
  local udid
  udid="$(resolve_or_create_simulator)"
  prepare_simulator "${udid}"
  build_and_install_app "${udid}"
  run_capture "${udid}"
}

run_frame_action() {
  bootstrap_dependencies
  run_frame
}

run_upload_action() {
  run_preflight_action
  run_upload
}

run_all_action() {
  run_capture_action
  run_frame_action
  run_upload
  log "All steps completed successfully"
}

ACTION="${1:-}"
case "${ACTION}" in
  preflight)
    run_preflight_action
    ;;
  capture)
    run_capture_action
    ;;
  frame)
    run_frame_action
    ;;
  upload)
    run_upload_action
    ;;
  all)
    run_all_action
    ;;
  *)
    usage
    exit 1
    ;;
esac
