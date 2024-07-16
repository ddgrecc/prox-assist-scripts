#!/bin/bash

CERTS_SOURCE_DIR="/etc/letsencrypt/live"
TARGET_DIR="/mnt/certs"

# Überprüfen, ob das Zielverzeichnis existiert
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Target directory $TARGET_DIR does not exist."
  exit 1
fi

# Temporäre Datei erstellen
TMPFILE="$(mktemp)"
trap 'rm -rf -- "$TMPFILE"' EXIT

# Durchsuche alle Zertifikatsdateien und extrahiere die Domains
find "${CERTS_SOURCE_DIR}" -name "cert*.pem" \
    -exec sh -c 'openssl x509 -noout -subject -in $0 | sed -s "s|.*= ||" | sed -z "s|\n|, |g"  && echo "$0" ' {} \; >"${TMPFILE}"

# Durchsuche die temporäre Datei nach allen Zertifikaten
while IFS= read -r line; do
  DOMAIN=$(echo "$line" | cut -d',' -f1)
  CERT_FILE=$(echo "$line" | sed -e 's|^.*, ||')
  CERT_DIR=$(dirname "${CERT_FILE}")
  
  if [ -n "$DOMAIN" ]; then
    DOMAIN_DIR="${TARGET_DIR}/${DOMAIN}"

    # Erstelle das Zielverzeichnis für die Domain, falls es nicht existiert
    mkdir -p "${DOMAIN_DIR}"

    # Kopiere alle relevanten Dateien (cert, chain, fullchain, privkey) in das Zielverzeichnis
    for FILE in cert*.pem chain*.pem fullchain*.pem privkey*.pem; do
      if [ -f "${CERT_DIR}/${FILE}" ]; then
        cp -L "${CERT_DIR}/${FILE}" "${DOMAIN_DIR}/"
      fi
    done

    echo "Copied ${DOMAIN} certificates and keys to ${DOMAIN_DIR}"
  fi
done < "${TMPFILE}"

echo "All certificates have been copied to ${TARGET_DIR}."
