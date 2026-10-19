#!/bin/sh

set -eu

# Ngăn Git Bash đổi /C=... của OpenSSL thành đường dẫn Windows.
MSYS_NO_PATHCONV=1
export MSYS_NO_PATHCONV

CERT_DIR="${CERT_DIR:-cau-hinh/nginx/certs}"

mkdir -p "$CERT_DIR"

CA_KEY="$CERT_DIR/ca.key"
CA_CRT="$CERT_DIR/ca.crt"
SERVER_KEY="$CERT_DIR/server.key"
SERVER_CRT="$CERT_DIR/server.crt"
CLIENT_KEY="$CERT_DIR/client.key"
CLIENT_CRT="$CERT_DIR/client.crt"
POSTGRES_KEY="$CERT_DIR/postgres.key"
POSTGRES_CRT="$CERT_DIR/postgres.crt"

echo "   GENERATE NGINX DEV/TEST CERTS"

CERT_SET_COMPLETE=true
for name in ca server client postgres; do
    key="$CERT_DIR/$name.key"
    cert="$CERT_DIR/$name.crt"

    if [ ! -f "$key" ] || [ ! -f "$cert" ]; then
        CERT_SET_COMPLETE=false
        break
    fi

    cert_pub=$(openssl x509 -in "$cert" -pubkey -noout 2>/dev/null | openssl pkey -pubin -pubout 2>/dev/null) || cert_pub=
    key_pub=$(openssl pkey -in "$key" -pubout 2>/dev/null) || key_pub=

    if [ -z "$cert_pub" ] || [ "$cert_pub" != "$key_pub" ]; then
        echo "Khóa không khớp chứng chỉ, sinh lại bộ chứng chỉ."
        CERT_SET_COMPLETE=false
        break
    fi
done

if [ "$CERT_SET_COMPLETE" = true ]; then
    echo
    echo "CA/server/client/PostgreSQL certificate set already exists - skip certificate generation."
else
    echo
    echo "Missing or inconsistent certificate set detected."
    echo "Generating a complete CA/server/client/PostgreSQL certificate set..."

    TMP_DIR=$(mktemp -d "$CERT_DIR/.certgen.XXXXXX")
    trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

    # 1. Development CA
    openssl genrsa \
        -out "$TMP_DIR/ca.key" \
        4096

    openssl req \
        -x509 \
        -new \
        -key "$TMP_DIR/ca.key" \
        -sha256 \
        -days 365 \
        -out "$TMP_DIR/ca.crt" \
        -subj "/C=VN/ST=HCM/L=HCM/O=TH-True-Milk/OU=Security/CN=TH-True-Milk Dev CA"

    # 2. Nginx server certificate
    openssl genrsa \
        -out "$TMP_DIR/server.key" \
        2048

    openssl req \
        -new \
        -key "$TMP_DIR/server.key" \
        -out "$TMP_DIR/server.csr" \
        -subj "/C=VN/ST=HCM/L=HCM/O=TH-True-Milk/OU=Security/CN=localhost"

    cat > "$TMP_DIR/server.ext" <<'EXT'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt_names

[alt_names]
DNS.1=localhost
DNS.2=nginx
IP.1=127.0.0.1
EXT

    openssl x509 \
        -req \
        -in "$TMP_DIR/server.csr" \
        -CA "$TMP_DIR/ca.crt" \
        -CAkey "$TMP_DIR/ca.key" \
        -CAcreateserial \
        -out "$TMP_DIR/server.crt" \
        -days 365 \
        -sha256 \
        -extfile "$TMP_DIR/server.ext"

    # 3. Admin client certificate
    openssl genrsa \
        -out "$TMP_DIR/client.key" \
        2048

    openssl req \
        -new \
        -key "$TMP_DIR/client.key" \
        -out "$TMP_DIR/client.csr" \
        -subj "/C=VN/ST=HCM/L=HCM/O=TH-True-Milk/OU=Security/CN=admin-client"

    cat > "$TMP_DIR/client.ext" <<'EXT'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature
extendedKeyUsage=clientAuth
EXT

    openssl x509 \
        -req \
        -in "$TMP_DIR/client.csr" \
        -CA "$TMP_DIR/ca.crt" \
        -CAkey "$TMP_DIR/ca.key" \
        -CAcreateserial \
        -out "$TMP_DIR/client.crt" \
        -days 365 \
        -sha256 \
        -extfile "$TMP_DIR/client.ext"

    # 4. PostgreSQL server certificate
    openssl genrsa \
        -out "$TMP_DIR/postgres.key" \
        2048

    openssl req \
        -new \
        -key "$TMP_DIR/postgres.key" \
        -out "$TMP_DIR/postgres.csr" \
        -subj "/C=VN/ST=HCM/L=HCM/O=TH-True-Milk/OU=Security/CN=db"

    cat > "$TMP_DIR/postgres.ext" <<'EXT'
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:db
EXT

    openssl x509 \
        -req \
        -in "$TMP_DIR/postgres.csr" \
        -CA "$TMP_DIR/ca.crt" \
        -CAkey "$TMP_DIR/ca.key" \
        -CAcreateserial \
        -out "$TMP_DIR/postgres.crt" \
        -days 365 \
        -sha256 \
        -extfile "$TMP_DIR/postgres.ext"

    # Replace the certificate set only after all generation steps succeed.
    chmod 600 \
        "$TMP_DIR/ca.key" \
        "$TMP_DIR/server.key" \
        "$TMP_DIR/client.key" \
        "$TMP_DIR/postgres.key"

    chmod 644 \
        "$TMP_DIR/ca.crt" \
        "$TMP_DIR/server.crt" \
        "$TMP_DIR/client.crt" \
        "$TMP_DIR/postgres.crt"

    cp "$TMP_DIR/ca.key" "$CA_KEY"
    cp "$TMP_DIR/ca.crt" "$CA_CRT"
    cp "$TMP_DIR/server.key" "$SERVER_KEY"
    cp "$TMP_DIR/server.crt" "$SERVER_CRT"
    cp "$TMP_DIR/client.key" "$CLIENT_KEY"
    cp "$TMP_DIR/client.crt" "$CLIENT_CRT"
    cp "$TMP_DIR/postgres.key" "$POSTGRES_KEY"
    cp "$TMP_DIR/postgres.crt" "$POSTGRES_CRT"

    chmod 600 "$CA_KEY" "$SERVER_KEY" "$CLIENT_KEY" "$POSTGRES_KEY"

    echo
    echo "Certificate set generated successfully."
fi

echo
echo "Verifying certificate chain..."

openssl verify \
    -CAfile "$CA_CRT" \
    "$SERVER_CRT"

openssl verify \
    -CAfile "$CA_CRT" \
    "$CLIENT_CRT"

openssl verify \
    -CAfile "$CA_CRT" \
    "$POSTGRES_CRT"

echo

echo "DEV/TEST CERTIFICATES READY"
