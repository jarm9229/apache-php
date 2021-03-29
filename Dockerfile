FROM php:7.3-apache
LABEL maintainer="Jesus Rodriguez <jarm9229@gmail.com>"

RUN a2enmod rewrite

# Install PHP extensions
RUN set -ex; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libbz2-dev \
		libjpeg-dev \
		libldap2-dev \
		libmemcached-dev \
		libpng-dev \
		libpq-dev \
		libzip-dev \
	; \
	\
	docker-php-ext-configure gd --with-png-dir=/usr --with-jpeg-dir=/usr; \
	debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
	docker-php-ext-configure ldap --with-libdir="lib/$debMultiarch"; \
	docker-php-ext-install \
		bz2 \
		gd \
		ldap \
		mysqli \
		pdo_mysql \
		pdo_pgsql \
		pgsql \
		zip \
	; \
	\
# pecl will claim success even if one install fails, so we need to perform each install separately
	pecl install APCu-5.1.17; \
	pecl install memcached-3.1.3; \
	pecl install redis-4.3.0; \
	\
	docker-php-ext-enable \
		apcu \
		memcached \
		redis \
	; \
	\
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*; \
	\
	echo "ServerName localhost" >> /etc/apache2/conf-available/fqdn.conf; \
	a2enconf fqdn
	

VOLUME /var/www/html

COPY index.php /var/www/html/index.php

RUN  chown -R www-data:www-data /var/www/html
EXPOSE 80/tcp 443/tcp
CMD ["apache2-foreground"]
