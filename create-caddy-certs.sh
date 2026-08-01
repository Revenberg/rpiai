#!/bin/bash
set -e

sudo apt update
sudo apt install libnss3-tools -y

wget -O /tmp/mkcert https://github.com/FiloSottile/mkcert/releases/latest/download/mkcert-v1.4.4-linux-arm64
chmod +x /tmp/mkcert
sudo mv /tmp/mkcert /usr/local/bin/mkcert

mkcert -version

mkcert -install

echo "=== Maak mkcert certificaat voor 192.168.1.1 en 192.168.1.2 ==="

cd ~/rpiai/caddy

mkdir -p ~/rpiai/caddy/certs

rm -f certs/*.pem

mkcert \
  -key-file ~/rpiai/caddy/certs/ip-key.pem \
  -cert-file ~/rpiai/caddy/certs/ip.pem \
  192.168.1.1 \
  192.168.1.2

mkcert -key-file ~/rpiai/caddy/certs/rpiai.local-key.pem \
       -cert-file ~/rpiai/caddy/certs/rpiai.local.pem \
       rpiai.local

#mv ~/rpiai/caddy/certs/*.pem certs/

echo "=== Certificaten geplaatst ==="
ls -l ~/rpiai/caddy/certs

echo "Klaar"
