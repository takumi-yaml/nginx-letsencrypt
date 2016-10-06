#!/bin/bash

set -euo pipefail

# Default other parameters
DOMAIN=""
SERVER=""
[ -n "${STAGING:-}" ] && SERVER="--server https://acme-staging.api.letsencrypt.org/directory"

# Generate strong DH parameters for nginx, if they don't already exist.
if [ ! -f /etc/ssl/dhparams.pem ]; then
  if [ -f /cache/dhparams.pem ]; then
    cp /cache/dhparams.pem /etc/ssl/dhparams.pem
  else
    openssl dhparam -out /etc/ssl/dhparams.pem 2048
    # Cache to a volume for next time?
    if [ -d /cache ]; then
      cp /etc/ssl/dhparams.pem /cache/dhparams.pem
    fi
  fi
fi

#create temp file storage
mkdir -p /var/cache/nginx
chown nginx:nginx /var/cache/nginx

mkdir -p /var/tmp/nginx
chown nginx:nginx /var/tmp/nginx


# Process templates
letscmd=" -d '${DOMAIN}'"


# Check if the SAN list has changed
if [ ! -f /etc/letsencrypt/san_list ]; then
 cat <<EOF >/etc/letsencrypt/san_list
 "${DOMAIN}"
EOF
  fresh=true
else 
  old_san=$(cat /etc/letsencrypt/san_list)
  if [ "${DOMAIN}" != "${old_san}" ]; then
    fresh=true
  else 
    fresh=false
  fi
fi

# Initial certificate request, but skip if cached
  if [ $fresh = true ]; then
    echo "The SAN list has changed, removing the old certificate and ask for a new one."
    rm -rf /etc/letsencrypt/{live,archive,keys,renewal}
   
   echo "letsencrypt certonly "${letscmd}" \
    --standalone \
    "${SERVER}" \
    --email "${EMAIL}" --agree-tos \
    --expand " > /etc/nginx/lets
    /bin/bash /etc/nginx/lets
  fi

#update the stored SAN list
echo "${DOMAIN}" > /etc/letsencrypt/san_list

# Template a cronjob to reissue the certificate with the webroot authenticator
  cat <<EOF >/etc/periodic/monthly/reissue
  #!/bin/sh
  set -euo pipefail
  # Certificate reissue
  letsencrypt certonly --force-renewal \
    --webroot \
    -w /etc/letsencrypt/webrootauth/ \
    ${letscmd} \
    "${SERVER}" \
    --email "${EMAIL}" --agree-tos \
    --expand
  # Reload nginx configuration to pick up the reissued certificates
  /usr/sbin/nginx -s reload
EOF

chmod +x /etc/periodic/monthly/reissue

# Kick off cron to reissue certificates as required
# Background the process and log to stderr
/usr/sbin/crond -f -d 8 &

echo Ready
# Launch nginx in the foreground
/usr/sbin/nginx -g "daemon off;"
