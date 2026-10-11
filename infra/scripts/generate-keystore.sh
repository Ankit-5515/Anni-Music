#!/usr/bin/env bash
# ============================================================================
# Anni Music — Android Release Keystore Generator (macOS / Linux)
# Generates app/android/keystore/anni-release-key.jks, writes key.properties,
# and exports a Base64-encoded keystore string for GitHub Actions secrets.
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ANDROID_DIR="${REPO_ROOT}/app/android"
KEYSTORE_DIR="${ANDROID_DIR}/keystore"
KEYSTORE_FILE="${KEYSTORE_DIR}/anni-release-key.jks"
KEY_PROPERTIES_FILE="${ANDROID_DIR}/key.properties"
BASE64_OUTPUT_FILE="${SCRIPT_DIR}/anni-release-key.base64.txt"

KEY_ALIAS="${ANNI_KEY_ALIAS:-anni_release_key}"
STORE_PASSWORD="${ANNI_KEYSTORE_PASSWORD:-$(openssl rand -hex 16)}"
KEY_PASSWORD="${ANNI_KEY_PASSWORD:-${STORE_PASSWORD}}"
VALIDITY_DAYS="10000"
DNAME="CN=Anni Music, OU=Mobile Engineering, O=Anni Labs, L=San Francisco, ST=California, C=US"

echo "================================================================"
echo "  Anni Music - Android Release Keystore Generator (POSIX)       "
echo "================================================================"

if ! command -v keytool >/dev/null 2>&1; then
  echo "ERROR: 'keytool' not found in PATH. Please install JDK 17+." >&2
  exit 1
fi

mkdir -p "${KEYSTORE_DIR}"

if [[ -f "${KEYSTORE_FILE}" ]]; then
  echo "WARNING: Existing keystore found. Backing up to ${KEYSTORE_FILE}.bak"
  cp -f "${KEYSTORE_FILE}" "${KEYSTORE_FILE}.bak"
  rm -f "${KEYSTORE_FILE}"
fi

echo ""
echo "[1/3] Generating RSA-2048 PKCS12 Release Keystore..."
keytool -genkeypair -v \
  -keystore "${KEYSTORE_FILE}" \
  -storetype PKCS12 \
  -alias "${KEY_ALIAS}" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "${VALIDITY_DAYS}" \
  -storepass "${STORE_PASSWORD}" \
  -keypass "${KEY_PASSWORD}" \
  -dname "${DNAME}"

echo ""
echo "[2/3] Writing ${KEY_PROPERTIES_FILE}..."
cat > "${KEY_PROPERTIES_FILE}" <<EOF
storePassword=${STORE_PASSWORD}
keyPassword=${KEY_PASSWORD}
keyAlias=${KEY_ALIAS}
storeFile=../keystore/anni-release-key.jks
EOF

echo ""
echo "[3/3] Encoding Keystore to Base64 for GitHub Actions..."
base64 < "${KEYSTORE_FILE}" | tr -d '\n\r' > "${BASE64_OUTPUT_FILE}"

echo ""
echo "================================================================"
echo "  SUCCESS! Release Signing Configured                           "
echo "================================================================"
echo "Keystore File   : ${KEYSTORE_FILE}"
echo "Key Properties  : ${KEY_PROPERTIES_FILE}"
echo "Base64 Output   : ${BASE64_OUTPUT_FILE}"
echo ""
echo "Configure these GitHub Repository Secrets (Settings -> Secrets -> Actions):"
echo "  ANNI_KEY_ALIAS          = ${KEY_ALIAS}"
echo "  ANNI_KEYSTORE_PASSWORD  = ${STORE_PASSWORD}"
echo "  ANNI_KEY_PASSWORD       = ${KEY_PASSWORD}"
echo "  ANNI_KEYSTORE_BASE64    = (contents of ${BASE64_OUTPUT_FILE})"
echo "================================================================"
