#!/bin/bash
set -e

cd /home/frappe

echo "Waiting for MariaDB..."
until mysqladmin ping -h mariadb -uroot -proot --silent; do
  sleep 2
done

echo "Waiting for Redis..."
until redis-cli -h redis ping | grep -q PONG; do
  sleep 2
done

# If bench exists, do NOT recreate anything
if [ -d "frappe-bench" ]; then
  cd frappe-bench

  # If site already exists → just start
  if [ -d "sites/hrms.localhost" ]; then
    echo "Site exists, starting bench..."
    exec bench start
  fi
fi

echo "Creating new bench..."

bench init \
  --frappe-branch version-14 \
  --skip-redis-config-generation \
  frappe-bench

cd frappe-bench

source env/bin/activate

pip uninstall -y urllib3 boto3 botocore || true
pip install "urllib3<2" "botocore<1.34" "boto3<1.34"

deactivate
# ---------------------------------------------------

bench set-config -g db_host mariadb
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

bench get-app erpnext --branch version-14
bench get-app hrms --branch version-14

echo "Creating site hrms.localhost..."

bench new-site hrms.localhost \
  --mariadb-root-password root \
  --admin-password admin \
  --no-mariadb-socket

bench --site hrms.localhost install-app erpnext
bench --site hrms.localhost install-app hrms

bench --site hrms.localhost set-config developer_mode 1
bench --site hrms.localhost enable-scheduler
bench --site hrms.localhost clear-cache
bench use hrms.localhost

exec bench start
