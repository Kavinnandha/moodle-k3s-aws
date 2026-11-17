#!/bin/sh
# Idempotent Moodle install/upgrade. Run by the moodle-install Job
# (k8s/moodle/install-job.yaml) on every deploy:
#   - empty database      -> install_database.php
#   - existing database   -> upgrade.php (applies new Moodle/plugin versions)
#
# The PHP snippets below are deliberately single-quoted: $m is a PHP variable.
# shellcheck disable=SC2016
set -eu
cd /var/www/html

php_db() {
  # Runs a PHP snippet with $m set to a mysqli connection (or null on failure).
  php -r 'mysqli_report(MYSQLI_REPORT_OFF);
    $m = @new mysqli(getenv("MOODLE_DB_HOST"), getenv("MOODLE_DB_USER"),
                     getenv("MOODLE_DB_PASSWORD"), getenv("MOODLE_DB_NAME"));
    if ($m->connect_errno) { $m = null; }
    '"$1"
}

echo "Waiting for MySQL at ${MOODLE_DB_HOST}..."
i=0
until php_db 'exit($m ? 0 : 1);'; do
  i=$((i + 1))
  if [ "$i" -ge 60 ]; then echo "MySQL not reachable after 5 minutes" >&2; exit 1; fi
  sleep 5
done

if php_db 'exit(($m && $m->query("SELECT 1 FROM mdl_config LIMIT 1")) ? 0 : 1);'; then
  echo "Moodle is already installed: running upgrade"
  php admin/cli/upgrade.php --non-interactive
else
  echo "Fresh database: installing Moodle"
  php admin/cli/install_database.php \
    --agree-license \
    --lang=en \
    --adminuser=admin \
    --adminpass="${MOODLE_ADMIN_PASSWORD}" \
    --adminemail="${MOODLE_ADMIN_EMAIL}" \
    --fullname="${MOODLE_SITE_FULLNAME:-Moodle on k3s (AWS lab)}" \
    --shortname="${MOODLE_SITE_SHORTNAME:-moodle-k3s}"
fi

echo "Purging caches"
php admin/cli/purge_caches.php
echo "Done"
