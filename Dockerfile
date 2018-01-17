#!/bin/bash
set -e

if [ ! -d '/var/lib/mysql/mysql' -a "${1%_safe}" = 'mysqld' ]; then
        if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
                echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
                echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
                exit 1
        fi

        mysql_install_db --user=mysql --datadir=/var/lib/mysql

        # These statements _must_ be on individual lines, and _must_ end with
        # semicolons (no line breaks or comments are permitted).
        # TODO proper SQL escaping on ALL the things D:
        TEMP_FILE='/tmp/mysql-first-time.sql'
        cat > "$TEMP_FILE" <<-EOSQL
                DELETE FROM mysql.user ;
                CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
                GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;
                DROP DATABASE IF EXISTS test ;
        EOSQL

        if [ "$MYSQL_DATABASE" ]; then
                echo "CREATE DATABASE IF NOT EXISTS $MYSQL_DATABASE ;" >> "$TEMP_FILE"
        fi

        if [ "$MYSQL_USER" -a "$MYSQL_PASSWORD" ]; then
                echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" >> "$TEMP_FILE"

                if [ "$MYSQL_DATABASE" ]; then
                        echo "GRANT ALL ON $MYSQL_DATABASE.* TO '$MYSQL_USER'@'%' ;" >> "$TEMP_FILE"
                fi
        fi

        echo 'FLUSH PRIVILEGES ;' >> "$TEMP_FILE"

        set -- "$@" --init-file="$TEMP_FILE"
fi

chown -R mysql:mysql /var/lib/mysql
exec "$@"
cat: CAT: No such file or directory
FROM ubuntu:trusty

RUN groupadd -r mysql && useradd -r -g mysql mysql

RUN apt-get update && \
    apt-get install -y curl binutils

RUN gpg --keyserver pgp.mit.edu --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5

RUN locale-gen en_US.UTF-8 &&\
    update-locale

ENV LANG en_US.UTF-8

ENV LANGUAGE en_US:en

ENV LC_ALL en_US.UTF-8

RUN curl -SL "http://dev.mysql.com/get/Downloads/MySQL-5.1/mysql-5.1.73-linux-x86_64-glibc23.tar.gz" -o mysql.tar.gz && \
    curl -SL "http://mysql.he.net/Downloads/MySQL-5.1/mysql-5.1.73-linux-x86_64-glibc23.tar.gz.asc" -o mysql.tar.gz.asc && \
    gpg --verify mysql.tar.gz.asc && \
    mkdir /usr/local/mysql && \
    tar -xzf mysql.tar.gz -C /usr/local/mysql --strip-components=1 && \
    rm mysql.tar.gz* && \
    rm -rf /usr/local/mysql/mysql-test /usr/local/mysql/sql-bench && \
    rm -rf /usr/local/mysql/bin/*-debug /usr/local/mysql/bin/*_embedded && \
    find /usr/local/mysql -type f -name "*.a" -delete && \
    { find /usr/local/mysql -type f -executable -exec strip --strip-all '{}' + || true; } && \
    apt-get purge -y --auto-remove binutils && \
    rm -rf /var/lib/apt/lists/*

ENV PATH $PATH:/usr/local/mysql/bin:/usr/local/mysql/scripts

WORKDIR /usr/local/mysql

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 3306

CMD ["mysqld", "--init-file=/var/lib/mysql/my.cnf", "--skip-name-resolve", "--datadir=/var/lib/mysql", "--user=mysql"]