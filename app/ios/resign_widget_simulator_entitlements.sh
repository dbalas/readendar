#!/usr/bin/env bash
# Simulator CodeSign uses empty *.xcent files and puts App Group / SIWA /
# application-identifier only in *-Simulated.xcent. On iOS 26+ that Simulated
# file is not applied to the running process or PlugInKit XPC peers, so:
#   - host writes to App Group fail (widget sync orphaned)
#   - chronod widget launches die with XPC_EXIT_REASON_FAULT
#
# Widget appex: stamp full Simulated into the embedded appex (Xcode will not
# re-codesign nested PlugIns after this Runner phase).
#
# Host: Xcode's final CodeSign runs AFTER shell scripts and re-applies the empty
# Runner.app.xcent. Copy a *filtered* entitlements plist (App Group only) over
# that .xcent — stamping SIWA / application-identifier / get-task-allow onto an
# adhoc simulator host makes SpringBoard deny launch
# (FBSOpenApplicationServiceErrorDomain). SIWA still needs a device / proper
# development signature; App Group is what unblocks widget sync on simulator.
set -euo pipefail

if [ "${PLATFORM_NAME:-}" != "iphonesimulator" ]; then
  exit 0
fi

IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"
if [ -z "$IDENTITY" ] || [ "$IDENTITY" = "Sign to Run Locally" ]; then
  IDENTITY="-"
fi

# Prints path to $1 Simulated.xcent (basename) or exits 1.
find_simulated_xcent() {
  _name="$1"
  if [ -f "${CONFIGURATION_TEMP_DIR}/${_name}" ]; then
    printf '%s\n' "${CONFIGURATION_TEMP_DIR}/${_name}"
    return 0
  fi
  _sibling="$(find "${CONFIGURATION_TEMP_DIR}/.." -name "${_name}" 2>/dev/null | head -1 || true)"
  if [ -n "${_sibling}" ] && [ -f "${_sibling}" ]; then
    printf '%s\n' "${_sibling}"
    return 0
  fi
  _sibling="$(find "${OBJROOT}" -name "${_name}" 2>/dev/null | head -1 || true)"
  if [ -n "${_sibling}" ] && [ -f "${_sibling}" ]; then
    printf '%s\n' "${_sibling}"
    return 0
  fi
  return 1
}

refresh_xcent_der() {
  _xcent="$1"
  if command -v derq >/dev/null 2>&1; then
    /usr/bin/derq query -f xml -i "${_xcent}" -o "${_xcent}.der" --raw
  fi
}

# Writes App-Group-only entitlements derived from Simulated into $2.
filter_host_simulator_entitlements() {
  _src="$1"
  _dst="$2"
  /usr/bin/python3 - "${_src}" "${_dst}" <<'PY'
import plistlib, sys
src, dst = sys.argv[1], sys.argv[2]
data = plistlib.loads(open(src, "rb").read())
groups = data.get("com.apple.security.application-groups")
if not groups:
    raise SystemExit("simulated host xcent missing application-groups")
# Adhoc simulator: only App Groups are launch-safe. SIWA / application-identifier
# / get-task-allow here → SBMainWorkspace launch denial.
filtered = {"com.apple.security.application-groups": groups}
plistlib.dump(filtered, open(dst, "wb"))
PY
}

APPEX="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/PlugIns/ReadendarWidget.appex"
if [ -d "$APPEX" ]; then
  WIDGET_XCENT="$(find_simulated_xcent 'ReadendarWidget.appex-Simulated.xcent' || true)"
  if [ -z "${WIDGET_XCENT}" ]; then
    echo "error: missing ReadendarWidget.appex-Simulated.xcent under ${CONFIGURATION_TEMP_DIR}/.. or ${OBJROOT}" >&2
    exit 1
  fi
  echo "Resigning ReadendarWidget.appex with $WIDGET_XCENT"
  /usr/bin/codesign --force --sign "$IDENTITY" \
    --entitlements "$WIDGET_XCENT" \
    --timestamp=none \
    --generate-entitlement-der \
    "$APPEX"
else
  echo "note: ReadendarWidget.appex not embedded; skip widget simulator entitlements resign"
fi

APP_BUNDLE="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
if [ ! -d "$APP_BUNDLE" ]; then
  exit 0
fi

HOST_XCENT="$(find_simulated_xcent 'Runner.app-Simulated.xcent' || true)"
if [ -z "${HOST_XCENT}" ]; then
  echo "warning: missing Runner.app-Simulated.xcent; re-sealing host with preserve-metadata only" >&2
  /usr/bin/codesign --force --sign "$IDENTITY" \
    --preserve-metadata=identifier,entitlements,flags \
    --timestamp=none \
    --generate-entitlement-der \
    "$APP_BUNDLE"
  exit 0
fi

HOST_FILTERED="$(dirname "$HOST_XCENT")/Runner.app-sim-appgroup.xcent"
filter_host_simulator_entitlements "$HOST_XCENT" "$HOST_FILTERED"
refresh_xcent_der "$HOST_FILTERED"

# Point Xcode's post-script CodeSign at App-Group-only entitlements.
HOST_CODE_SIGN_XCENT="$(dirname "$HOST_XCENT")/Runner.app.xcent"
echo "Installing App-Group-only entitlements → $HOST_CODE_SIGN_XCENT for final CodeSign"
cp -f "$HOST_FILTERED" "$HOST_CODE_SIGN_XCENT"
refresh_xcent_der "$HOST_CODE_SIGN_XCENT"

echo "Resigning ${WRAPPER_NAME} with App Group only (simulator launch-safe)"
/usr/bin/codesign --force --sign "$IDENTITY" \
  --entitlements "$HOST_FILTERED" \
  --timestamp=none \
  --generate-entitlement-der \
  "$APP_BUNDLE"
