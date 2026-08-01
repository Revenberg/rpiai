#!/bin/sh

DB="/app/backend/data/webui.db"
ENV_FILE="/work/.env"

EMAIL="pi@home.com"
NAME="Pi Admin"
USERNAME="admin"
PASSWORD="admin"

echo "Wachten op database..."

while [ ! -f "$DB" ]
do
    sleep 5
done

echo "Database gevonden"

if ! command -v python3 >/dev/null 2>&1; then
    echo "Fout: python3 niet gevonden in deze container."
    echo "Gebruik een image met python3 (of voer dit script in samatha-ai uit)."
    exit 1
fi

echo "bcrypt hash maken..."

HASH=$(python3 - <<EOF
import bcrypt
print(bcrypt.hashpw(b"$PASSWORD", bcrypt.gensalt()).decode())
EOF
)

if [ -z "$HASH" ]; then
    echo "Fout: kon bcrypt hash niet genereren."
    exit 1
fi

API_KEY=$(python3 - <<EOF
import secrets
print(secrets.token_urlsafe(32))
EOF
)

if [ -z "$API_KEY" ]; then
    echo "Fout: kon API key niet genereren."
    exit 1
fi

echo "Bestaande gebruiker verwijderen..."

sqlite3 "$DB" "
DELETE FROM auth WHERE email='$EMAIL';
DELETE FROM user WHERE email='$EMAIL';
" || true

NOW=$(date +%s)
ID=$(cat /proc/sys/kernel/random/uuid)


echo "Auth toevoegen..."

sqlite3 "$DB" "
INSERT INTO auth
(
id,
email,
password,
active
)
VALUES
(
'$ID',
'$EMAIL',
'$HASH',
1
);
"

if sqlite3 "$DB" "PRAGMA table_info(auth);" | grep -q "|api_key|"; then
    echo "API key toevoegen aan auth..."
    sqlite3 "$DB" "
    UPDATE auth
    SET api_key='$API_KEY'
    WHERE email='$EMAIL';
    "
fi


echo "User toevoegen..."

sqlite3 "$DB" "
INSERT INTO user
(
id,
name,
email,
role,
profile_image_url,
created_at,
updated_at,
last_active_at,
username
)
VALUES
(
'$ID',
'$NAME',
'$EMAIL',
'admin',
'/user.png',
$NOW,
$NOW,
$NOW,
'$USERNAME'
);
"

if sqlite3 "$DB" "PRAGMA table_info(user);" | grep -q "|api_key|"; then
    echo "API key toevoegen aan user..."
    sqlite3 "$DB" "
    UPDATE user
    SET api_key='$API_KEY'
    WHERE email='$EMAIL';
    "
fi


echo "Controle:"
sqlite3 "$DB" \
"SELECT name,email,role FROM user WHERE email='$EMAIL';"

echo "API key voor $EMAIL:"
echo "$API_KEY"

if [ -f "$ENV_FILE" ]; then
    echo "SAMATHA_API_KEY opslaan in .env voor Caddy/Jarvis..."
    if grep -q '^SAMATHA_API_KEY=' "$ENV_FILE"; then
        sed -i "s|^SAMATHA_API_KEY=.*|SAMATHA_API_KEY=$API_KEY|" "$ENV_FILE"
    else
        printf "\nSAMATHA_API_KEY=%s\n" "$API_KEY" >> "$ENV_FILE"
    fi
    echo "SAMATHA_API_KEY bijgewerkt in .env"
else
    echo "Waarschuwing: $ENV_FILE niet gevonden, .env niet bijgewerkt"
fi

echo "Klaar"

