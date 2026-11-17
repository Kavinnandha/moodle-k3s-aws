# Moodle 4.5 LTS + CodeRunner, on the PHP 8.3 / Apache runtime image that
# Moodle HQ maintains (the same base moodle-docker uses).
#
# Moodle code is baked into the image and owned by root, so the web server
# (www-data) can read it but not modify it. Only /var/www/moodledata, a PVC,
# is writable.
FROM moodlehq/moodle-php-apache:8.3-bookworm

# "latest-405" follows 4.5.x security releases. Pin an exact tarball
# (e.g. moodle-4.5.N.tgz) if you need byte-for-byte reproducible builds.
ARG MOODLE_TGZ_URL=https://packaging.moodle.org/stable405/moodle-latest-405.tgz
ARG CODERUNNER_VERSION=v5.10.6
ARG ADAPTIVE_CR_VERSION=v1.4.8

RUN set -eux; \
    rm -rf /var/www/html; \
    curl -fsSL "$MOODLE_TGZ_URL" | tar -xz -C /var/www; \
    mv /var/www/moodle /var/www/html; \
    mkdir -p /var/www/html/question/type/coderunner \
             /var/www/html/question/behaviour/adaptive_adapted_for_coderunner; \
    curl -fsSL "https://github.com/trampgeek/moodle-qtype_coderunner/archive/refs/tags/${CODERUNNER_VERSION}.tar.gz" \
      | tar -xz --strip-components=1 -C /var/www/html/question/type/coderunner; \
    curl -fsSL "https://github.com/trampgeek/moodle-qbehaviour_adaptive_adapted_for_coderunner/archive/refs/tags/${ADAPTIVE_CR_VERSION}.tar.gz" \
      | tar -xz --strip-components=1 -C /var/www/html/question/behaviour/adaptive_adapted_for_coderunner; \
    chown -R root:root /var/www/html; \
    mkdir -p /var/www/moodledata; \
    chown www-data:www-data /var/www/moodledata

COPY config.php /var/www/html/config.php
COPY moodle.ini /usr/local/etc/php/conf.d/zz-moodle.ini
COPY moodle-install.sh /usr/local/bin/moodle-install.sh
RUN chmod 0644 /var/www/html/config.php && chmod 0755 /usr/local/bin/moodle-install.sh

WORKDIR /var/www/html
