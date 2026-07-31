#!/bin/bash

rm -f /tmp/caddy_test.html

for url in \
"https://192.168.1.1/" \
"https://rpiai.local/" \
"https://rpiai.local/readme/" \
"https://rpiai.local/readme" \
"https://rpiai.local/monitor/"
do
    echo "=============================="
    echo "$url"

    rm -f /tmp/caddy_test.html

    curl -k -s -L -o /tmp/caddy_test.html \
    -w "HTTP %{http_code} | %{content_type} | %{size_download} bytes\n" "$url"

    if [ "$?" -ne 0 ]; then
        echo "curl fout"
    elif [ -s /tmp/caddy_test.html ]; then
        head -5 /tmp/caddy_test.html
    else
        echo "lege response"
    fi
done

echo "IP"
curl -k -s -o /dev/null -w "HTTP %{http_code} %{content_type} %{size_download}\n" https://192.168.1.1/

echo "DNS"
curl -k -s -o /dev/null -w "HTTP %{http_code} %{content_type} %{size_download}\n" https://rpiai.local/
