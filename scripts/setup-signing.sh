#!/usr/bin/env bash
# One-time setup: creates a self-signed "Pinpin Local Signing" code-signing identity in your login
# keychain. build-app.sh signs with it, so every build has the same signature and macOS keeps
# Pinpin's Screen Recording / Accessibility permissions across rebuilds.
set -euo pipefail

NAME="Pinpin Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
  echo "\"$NAME\" already exists."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CNF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -config "$TMP/cert.cnf" -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null

# macOS's importer only understands the legacy PKCS#12 algorithms.
PASS="pinpin"
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
  -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1 \
  -passout "pass:$PASS" -out "$TMP/identity.p12"

security import "$TMP/identity.p12" -k "$KEYCHAIN" -P "$PASS" -T /usr/bin/codesign

echo "Created \"$NAME\". Rebuild with ./scripts/build-app.sh"
