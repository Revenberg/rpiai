#!/bin/sh

DB="/app/backend/data/webui.db"

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

echo "Bestaande gebruiker verwijderen..."

sqlite3 "$DB" "
DELETE FROM auth WHERE email='$EMAIL';
DELETE FROM user WHERE email='$EMAIL';
" || true


echo "bcrypt hash maken..."

HASH=$(python3 - <<EOF
import bcrypt
print(bcrypt.hashpw(b"$PASSWORD", bcrypt.gensalt()).decode())
EOF
)

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


echo "Controle:"
sqlite3 "$DB" \
"SELECT name,email,role FROM user WHERE email='$EMAIL';"

echo "Klaar"

