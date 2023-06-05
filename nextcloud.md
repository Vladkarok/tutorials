# Nextcloud
# Nextcloud 26

Source - https://www.c-rieger.de/nextcloud-installationsanleitung-apache2-fast-track/

- [Nextcloud](#nextcloud)
- [Nextcloud 26](#nextcloud-26)
  - [System preparation](#system-preparation)
  - [Installation MariaDB 10.8](#installation-mariadb-108)
  - [Installation Redis and PHP 8.1](#installation-redis-and-php-81)
  - [Redis adjustments](#redis-adjustments)
  - [Apache2 customization](#apache2-customization)
  - [Download Nextcloud latest](#download-nextcloud-latest)
  - [Installation of Nextcloud](#installation-of-nextcloud)
  - [Cronjob](#cronjob)
  - [More hardening](#more-hardening)
- [Nextcloud 21](#nextcloud-21)
  - [Apache2 customization](#apache2-customization-1)
  - [Download Nextcloud 21](#download-nextcloud-21)
  - [Installation of Nextcloud](#installation-of-nextcloud-1)
  - [Cronjob](#cronjob-1)
  - [More hardening](#more-hardening-1)

## System preparation

Enable root shell
```
sudo -c
```
And execute commands:
```sh
apt update && apt upgrade -y
```
```sh
apt install -y \
apt-transport-https bash-completion bzip2 ca-certificates cron curl dialog \
dirmngr ffmpeg ghostscript git gpg gnupg gnupg2 htop jq libfile-fcntllock-perl \
libfontconfig1 libfuse2 locate lsb-release net-tools rsyslog screen smbclient \
socat software-properties-common ssl-cert tree ubuntu-keyring unzip wget zip
```
```sh
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```
and reboot
```
reboot now
```
After reboot:
```sh
sudo -s
apt update && apt upgrade -y && apt autoremove -y && apt autoclean -y
```
Create Nextcloud directory: `/var/nc_data`
```sh
mkdir -p /var/www /var/nc_data
chown -R www-data:www-data /var/nc_data /var/www
```
## Installation MariaDB 10.8

```sh
MARIADB_VERSION="10.8"
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-$MARIADB_VERSION"
```

```
apt update && apt install -y mariadb-server
```
Start `mysql_secure_installation` and fill it

```
mysql_secure_installation
```
sample output:
```
Enter current password for root (enter for none): <ENTER> or type the password
Switch to unix_socket authentication [Y/n] Y
Set root password? [Y/n] Y
Remove anonymous users? [Y/n] Y
Disallow root login remotely? [Y/n] Y
Remove test database and access to it? [Y/n] Y
Reload privilege tables now? [Y/n] Y
```
Configure Maria-DB
```
service mariadb stop && mv /etc/mysql/my.cnf /etc/mysql/my.cnf.bak && nano /etc/mysql/my.cnf
```
and fill it with the following content:
```conf
[client]
default-character-set = utf8mb4
port = 3306
socket = /var/run/mysqld/mysqld.sock
[mysqld_safe]
log_error = /var/log/mysql/mysql_error.log
nice = 0
socket = /var/run/mysqld/mysqld.sock
[mysqld]
basedir = /usr
bind-address = 127.0.0.1
binlog_format = ROW
bulk_insert_buffer_size = 16M
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
concurrent_insert = 2
connect_timeout = 5
datadir = /var/lib/mysql
default_storage_engine = InnoDB
expire_logs_days = 2
general_log_file = /var/log/mysql/mysql.log
general_log = 0
innodb_buffer_pool_size = 2G
innodb_buffer_pool_instances = 1
innodb_flush_log_at_trx_commit = 2
innodb_log_buffer_size = 32M
innodb_max_dirty_pages_pct = 90
innodb_file_per_table = 1
innodb_open_files = 400
innodb_io_capacity = 4000
innodb_flush_method = O_DIRECT
innodb_read_only_compressed=OFF
key_buffer_size = 128M
lc_messages_dir = /usr/share/mysql
lc_messages = en_US
log_bin = /var/log/mysql/mariadb-bin
log_bin_index = /var/log/mysql/mariadb-bin.index
log_error = /var/log/mysql/mysql_error.log
log_slow_verbosity = query_plan
log_warnings = 2
long_query_time = 1
max_allowed_packet = 16M
max_binlog_size = 100M
max_connections = 2000
max_heap_table_size = 64M
myisam_recover_options = BACKUP
myisam_sort_buffer_size = 512M
port = 3306
pid-file = /var/run/mysqld/mysqld.pid
query_cache_limit = 2M
query_cache_size = 64M
query_cache_type = 1
query_cache_min_res_unit = 2k
read_buffer_size = 2M
read_rnd_buffer_size = 1M
skip-external-locking
skip-name-resolve
slow_query_log_file = /var/log/mysql/mariadb-slow.log
slow-query-log = 1
socket = /var/run/mysqld/mysqld.sock
sort_buffer_size = 4M
table_open_cache = 400
thread_cache_size = 128
tmp_table_size = 64M
tmpdir = /tmp
transaction_isolation = READ-COMMITTED
#unix_socket=OFF
user = mysql
wait_timeout = 600
[mysqldump]
max_allowed_packet = 16M
quick
quote-names
[isamchk]
key_buffer = 16M
```
```
service mariadb restart
```
Create database for Nextcloud and user with access to it.
> In this command `identified by 'nextcloud'` the `nextcloud` password is as EXAMPLE, modify it by your own!
```sh
mysql -uroot -p -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci; CREATE USER nextcloud@localhost identified by 'nextcloud'; GRANT ALL PRIVILEGES on nextcloud.* to nextcloud@localhost; FLUSH privileges;"
```

## Installation Redis and PHP 8.1
```
apt install -y redis-server libapache2-mod-php8.1 php-common \
php8.1-{fpm,gd,curl,xml,zip,intl,mbstring,bz2,ldap,apcu,bcmath,gmp,imagick,igbinary,mysql,redis,smbclient,cli,common,opcache,readline} \
imagemagick --allow-change-held-packages
```
Change your timezone: (in our case it is Kyiv)
```
timedatectl set-timezone Europe/Kyiv
```
Create backups of configuration files before modifying:
```sh
cp /etc/php/8.1/fpm/pool.d/www.conf /etc/php/8.1/fpm/pool.d/www.conf.bak
cp /etc/php/8.1/fpm/php-fpm.conf /etc/php/8.1/fpm/php-fpm.conf.bak
cp /etc/php/8.1/cli/php.ini /etc/php/8.1/cli/php.ini.bak
cp /etc/php/8.1/fpm/php.ini /etc/php/8.1/fpm/php.ini.bak
cp /etc/php/8.1/fpm/php-fpm.conf /etc/php/8.1/fpm/php-fpm.conf.bak
cp /etc/php/8.1/mods-available/apcu.ini /etc/php/8.1/mods-available/apcu.ini.bak
cp /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml.bak
```
Calculate some specific to your system parameters (just execute the following commands)
```bash
AvailableRAM=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
AverageFPM=$(ps --no-headers -o 'rss,cmd' -C php-fpm8.1 | awk '{ sum+=$1 } END { printf ("%d\n", sum/NR/1024,"M") }')
FPMS=$((AvailableRAM/AverageFPM))
PMaxSS=$((FPMS*2/3))
PMinSS=$((PMaxSS/2))
PStartS=$(((PMaxSS+PMinSS)/2))
```
```sh
sed -i "s/;env\[HOSTNAME\] = /env[HOSTNAME] = /" /etc/php/8.1/fpm/pool.d/www.conf
sed -i "s/;env\[TMP\] = /env[TMP] = /" /etc/php/8.1/fpm/pool.d/www.conf
sed -i "s/;env\[TMPDIR\] = /env[TMPDIR] = /" /etc/php/8.1/fpm/pool.d/www.conf
sed -i "s/;env\[TEMP\] = /env[TEMP] = /" /etc/php/8.1/fpm/pool.d/www.conf
sed -i "s/;env\[PATH\] = /env[PATH] = /" /etc/php/8.1/fpm/pool.d/www.conf
sed -i 's/pm.max_children =.*/pm.max_children = '$FPMS'/' /etc/php/8.1/fpm/pool.d/www.conf
sed -i 's/pm.start_servers =.*/pm.start_servers = '$PStartS'/' /etc/php/8.1/fpm/pool.d/www.conf
sed -i 's/pm.min_spare_servers =.*/pm.min_spare_servers = '$PMinSS'/' /etc/php/8.1/fpm/pool.d/www.conf
sed -i 's/pm.max_spare_servers =.*/pm.max_spare_servers = '$PMaxSS'/' /etc/php/8.1/fpm/pool.d/www.conf
sed -i "s/;pm.max_requests =.*/pm.max_requests = 1000/" /etc/php/8.1/fpm/pool.d/www.conf
sed -i "s/allow_url_fopen =.*/allow_url_fopen = 1/" /etc/php/8.1/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo.*/cgi.fix_pathinfo=1/" /etc/php/8.1/fpm/php.ini

sed -i "s/output_buffering =.*/output_buffering = 'Off'/" /etc/php/8.1/cli/php.ini
sed -i "s/max_execution_time =.*/max_execution_time = 3600/" /etc/php/8.1/cli/php.ini
sed -i "s/max_input_time =.*/max_input_time = 3600/" /etc/php/8.1/cli/php.ini
sed -i "s/post_max_size =.*/post_max_size = 10240M/" /etc/php/8.1/cli/php.ini
sed -i "s/upload_max_filesize =.*/upload_max_filesize = 10240M/" /etc/php/8.1/cli/php.ini
sed -i "s/;date.timezone.*/date.timezone = Europe\/\Berlin/" /etc/php/8.1/cli/php.ini
sed -i "s/;cgi.fix_pathinfo.*/cgi.fix_pathinfo=1/" /etc/php/8.1/cli/php.ini

sed -i "s/memory_limit = 128M/memory_limit = 1024M/" /etc/php/8.1/fpm/php.ini
sed -i "s/output_buffering =.*/output_buffering = 'Off'/" /etc/php/8.1/fpm/php.ini
sed -i "s/max_execution_time =.*/max_execution_time = 3600/" /etc/php/8.1/fpm/php.ini
sed -i "s/max_input_time =.*/max_input_time = 3600/" /etc/php/8.1/fpm/php.ini
sed -i "s/post_max_size =.*/post_max_size = 10240M/" /etc/php/8.1/fpm/php.ini
sed -i "s/upload_max_filesize =.*/upload_max_filesize = 10240M/" /etc/php/8.1/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = Europe\/\Berlin/" /etc/php/8.1/fpm/php.ini
sed -i "s/;session.cookie_secure.*/session.cookie_secure = True/" /etc/php/8.1/fpm/php.ini
sed -i "s/;opcache.enable=.*/opcache.enable=1/" /etc/php/8.1/fpm/php.ini
sed -i "s/;opcache.enable_cli=.*/opcache.enable_cli=1/" /etc/php/8.1/fpm/php.ini
sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=256/" /etc/php/8.1/fpm/php.ini
sed -i "s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=64/" /etc/php/8.1/fpm/php.ini
sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=100000/" /etc/php/8.1/fpm/php.ini
sed -i "s/;opcache.revalidate_freq=.*/opcache.revalidate_freq=1/" /etc/php/8.1/fpm/php.ini
sed -i "s/;opcache.save_comments=.*/opcache.save_comments=1/" /etc/php/8.1/fpm/php.ini

sed -i "s|;emergency_restart_threshold.*|emergency_restart_threshold = 10|g" /etc/php/8.1/fpm/php-fpm.conf
sed -i "s|;emergency_restart_interval.*|emergency_restart_interval = 1m|g" /etc/php/8.1/fpm/php-fpm.conf
sed -i "s|;process_control_timeout.*|process_control_timeout = 10|g" /etc/php/8.1/fpm/php-fpm.conf

sed -i '$aapc.enable_cli=1' /etc/php/8.1/mods-available/apcu.ini

sed -i "s/rights=\"none\" pattern=\"PS\"/rights=\"read|write\" pattern=\"PS\"/" /etc/ImageMagick-6/policy.xml
sed -i "s/rights=\"none\" pattern=\"EPS\"/rights=\"read|write\" pattern=\"EPS\"/" /etc/ImageMagick-6/policy.xml
sed -i "s/rights=\"none\" pattern=\"PDF\"/rights=\"read|write\" pattern=\"PDF\"/" /etc/ImageMagick-6/policy.xml
sed -i "s/rights=\"none\" pattern=\"XPS\"/rights=\"read|write\" pattern=\"XPS\"/" /etc/ImageMagick-6/policy.xml

sed -i '$a[mysql]' /etc/php/8.1/mods-available/mysqli.ini
sed -i '$amysql.allow_local_infile=On' /etc/php/8.1/mods-available/mysqli.ini
sed -i '$amysql.allow_persistent=On' /etc/php/8.1/mods-available/mysqli.ini
sed -i '$amysql.cache_size=2000' /etc/php/8.1/mods-available/mysqli.ini
sed -i '$amysql.max_persistent=-1' /etc/php/8.1/mods-available/mysqli.ini
sed -i '$amysql.max_links=-1' /etc/php/8.1/mods-available/mysqli.ini
sed -i '$amysql.default_port=3306' /etc/php/8.1/mods-available/mysqli.ini
sed -i '$amysql.connect_timeout=60' /etc/php/8.1/mods-available/mysqli.ini
sed -i '$amysql.trace_mode=Off' /etc/php/8.1/mods-available/mysqli.ini
```
Restart services
```
systemctl restart php8.1-fpm
a2dismod php8.1 && a2dismod mpm_prefork
a2enmod proxy_fcgi setenvif mpm_event http2
systemctl restart apache2.service
a2enconf php8.1-fpm
systemctl restart apache2.service php8.1-fpm
```

## Redis adjustments

```
cp /etc/redis/redis.conf /etc/redis/redis.conf.bak
sed -i "s/port 6379/port 0/" /etc/redis/redis.conf
sed -i s/\#\ unixsocket/\unixsocket/g /etc/redis/redis.conf
sed -i "s/unixsocketperm 700/unixsocketperm 770/" /etc/redis/redis.conf 
sed -i "s/# maxclients 10000/maxclients 10240/" /etc/redis/redis.conf
usermod -aG redis www-data
cp /etc/sysctl.conf /etc/sysctl.conf.bak
sed -i '$avm.overcommit_memory = 1' /etc/sysctl.conf
sysctl -p
```
## Apache2 customization

```
a2enmod rewrite headers env dir mime
nano /etc/apache2/mods-available/http2.conf
```
adjust
```
# mod_http2 doesn't work with mpm_prefork
<IfModule !mpm_prefork>
Protocols h2 h2c http/1.1
H2Direct on
H2StreamMaxMemSize 5120000000
[...]
```
```
systemctl restart apache2.service
```
```
cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/001-nextcloud.conf
```
```
a2dissite 000-default.conf
```
```
nano /etc/apache2/sites-available/001-nextcloud.conf
```
paste this replacing `yourdomain.com`

```
<VirtualHost *:80>
ServerName yourdomain.com
ServerAlias yourdomain.com
ServerAdmin mail@yourdomain.com
DocumentRoot /var/www/html/nextcloud
ErrorLog /var/log/apache2/error.log
CustomLog /var/log/apache2/access.log combined
RewriteEngine on
RewriteCond %{SERVER_NAME} =yourdomain.com
RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
```
activate vHost
```
a2ensite 001-nextcloud.conf && systemctl restart apache2.service
```

**Certbot**
```
apt install -y certbot python3-certbot-apache
certbot --apache
```
Nextcloud vHost: accept all lines and adjust values ​​to your system
```
mv /etc/apache2/sites-available/001-nextcloud-le-ssl.conf /etc/apache2/sites-available/001-nextcloud-le-ssl.conf.bak
```
```
nano /etc/apache2/sites-available/001-nextcloud-le-ssl.conf
```
```apache
<IfModule mod_ssl.c>
SSLUseStapling on
SSLStaplingCache shmcb:/var/run/ocsp(128000)
<VirtualHost *:443>
SSLCertificateFile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
SSLCACertificateFile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
SSLCertificateKeyFile /etc/letsencrypt/live/yourdomain.com/privkey.pem
#######################################################################
# For self-signed-certificates only!
# SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
# SSLCACertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
# SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
#######################################################################
Protocols h2 h2c http/1.1
Header add Strict-Transport-Security: "max-age=15552000;includeSubdomains"
ServerAdmin mail@yourdomain.com
ServerName yourdomain.com
ServerAlias yourdomain.com
SSLEngine on
SSLCompression off
SSLOptions +StrictRequire
SSLProtocol -all +TLSv1.3 +TLSv1.2
SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
SSLHonorCipherOrder off
SSLSessionTickets off
ServerSignature off
SSLStaplingResponderTimeout 5
SSLStaplingReturnResponderErrors off
SSLOpenSSLConfCmd Curves X448:secp521r1:secp384r1:prime256v1
SSLOpenSSLConfCmd ECDHParameters secp384r1
LogLevel warn
CustomLog /var/log/apache2/access.log combined
ErrorLog /var/log/apache2/error.log
DocumentRoot /var/www/html/nextcloud
<Directory /var/www/html/nextcloud/>
Options Indexes FollowSymLinks
AllowOverride All
Require all granted
Satisfy Any
</Directory>
<IfModule mod_dav.c>
Dav off
</IfModule>
<Directory /var/nc_data/>
Require all denied
</Directory>
<Files ".ht*">
Require all denied
</Files>
TraceEnable off
RewriteEngine On
RewriteCond %{REQUEST_METHOD} ^TRACK
RewriteRule .* - [R=405,L]
SetEnv HOME /var/www/html/nextcloud
SetEnv HTTP_HOME /var/www/html/nextcloud
<IfModule mod_reqtimeout.c>
RequestReadTimeout body=0
</IfModule>
</VirtualHost>
</IfModule>
```
Expand and enable security

```
openssl dhparam -dsaparam -out /etc/ssl/certs/dhparam.pem 4096
cat /etc/ssl/certs/dhparam.pem >> /etc/letsencrypt/live/yourdomain.com/fullchain.pem
```
Editing the Apache2 configuration file:
```
nano /etc/apache2/apache2.conf
```
```apache
ServerName yourdomain.com
[...]
<Directory /var/www/>
Options FollowSymLinks MultiViews
AllowOverride All
Require all granted
</Directory>
```
```
systemctl restart apache2.service
```


## Download Nextcloud latest
> If you want to download other version, replace `latest.zip` with `nextcloud-21.0.9.zip` to download **21.0.9** version for example
```
wget https://download.nextcloud.com/server/releases/latest.zip
unzip latest.zip && mv nextcloud/ /var/www/html/ && chown -R www-data:www-data /var/www/html/nextcloud && rm -f latest.zip
```


## Installation of Nextcloud
> `Nextcloud-Admin` and `Nextcloud-Admin-Passswort` change to you own

```
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:install --database "mysql" --database-name "nextcloud" --database-user "nextcloud" --database-pass "nextcloud" --admin-user "Nextcloud-Admin" --admin-pass "Nextcloud-Admin-Passswort" --data-dir "/var/nc_data"
```
correct config.php – add the lines:
```
sudo -u www-data nano /var/www/html/nextcloud/config/config.php
```
```apache
[...]
),
'datadirectory' => '/var/nc_data',
'overwrite.cli.url' => 'https://yourdomain.com/',
'htaccess.RewriteBase' => '/',
[...]
```
Correct Nextcloud .htaccess
```
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:update:htaccess
```
Nextcloud Customizations
```sh
mkdir -p /var/log/nextcloud/
chown -R www-data:www-data /var/log/nextcloud
sudo -u www-data cp /var/www/html/nextcloud/config/config.php /var/www/html/nextcloud/config/config.php.bak
sudo -u www-data sed -i 's/^[ ]*//' /var/www/html/nextcloud/config/config.php
sudo -u www-data sed -i '/);/d' /var/www/html/nextcloud/config/config.php
```
```sh
sudo -u www-data cat <<EOF >>/var/www/html/nextcloud/config/config.php
'activity_expire_days' => 14,
'allow_local_remote_servers' => true,
'auth.bruteforce.protection.enabled' => true,
'blacklisted_files' => 
array (
0 => '.htaccess',
1 => 'Thumbs.db',
2 => 'thumbs.db',
),
'cron_log' => true,
'default_phone_region' => 'DE',
'defaultapp' => 'files,dashboard',
'enable_previews' => true,
'enabledPreviewProviders' => 
array (
0 => 'OC\Preview\PNG',
1 => 'OC\Preview\JPEG',
2 => 'OC\Preview\GIF',
3 => 'OC\Preview\BMP',
4 => 'OC\Preview\XBitmap',
5 => 'OC\Preview\Movie',
6 => 'OC\Preview\PDF',
7 => 'OC\Preview\MP3',
8 => 'OC\Preview\TXT',
9 => 'OC\Preview\MarkDown',
),
'filesystem_check_changes' => 0,
'filelocking.enabled' => 'true',
'htaccess.RewriteBase' => '/',
'integrity.check.disabled' => false,
'knowledgebaseenabled' => false,
'logfile' => '/var/log/nextcloud/nextcloud.log',
'loglevel' => 2,
'logtimezone' => 'Europe/Berlin',
'log_rotate_size' => '104857600',
'maintenance' => false,
'maintenance_window_start' => 1,
'memcache.local' => '\OC\Memcache\APCu',
'memcache.locking' => '\OC\Memcache\Redis',
'overwriteprotocol' => 'https',
'preview_max_x' => 1024,
'preview_max_y' => 768,
'preview_max_scale_factor' => 1,
'profile.enabled' => false,
'redis' => 
array (
'host' => '/var/run/redis/redis-server.sock',
'port' => 0,
'timeout' => 0.5,
'dbindex' => 1,
),
'quota_include_external_storage' => false,
'share_folder' => '/Freigaben',
'skeletondirectory' => '',
'theme' => '',
'trashbin_retention_obligation' => 'auto, 7',
'updater.release.channel' => 'stable',
);
EOF
```
```
sudo -u www-data php /var/www/html/nextcloud occ config:system:set remember_login_cookie_lifetime --value="1800"
sudo -u www-data php /var/www/html/nextcloud occ config:system:set simpleSignUpLink.shown --type=bool --value=false
sudo -u www-data php /var/www/html/nextcloud occ config:system:set versions_retention_obligation --value="auto, 365"
sudo -u www-data php /var/www/html/nextcloud occ config:system:set loglevel --value=2
sudo -u www-data php /var/www/html/nextcloud/occ config:system:set trusted_domains 1 --value=yourdomain.com
sudo -u www-data php /var/www/html/nextcloud/occ config:app:set settings profile_enabled_by_default --value="0"
```
Optional Nextcloud Office (~ 400MB)
```
sudo -u www-data /usr/bin/php /var/www/html/nextcloud/occ app:install richdocuments
sudo -u www-data /usr/bin/php /var/www/html/nextcloud/occ app:install richdocumentscode
a2enmod ssl && a2ensite 001-nextcloud.conf 001-nextcloud-le-ssl.conf
systemctl restart php8.1-fpm.service redis-server.service apache2.service
```
## Cronjob
```
crontab -u www-data -e
```
```
*/5 * * * * php -f /var/www/html/nextcloud/cron.php > /dev/null 2>&1
```
save&exit

```
sudo -u www-data php /var/www/html/nextcloud/occ background:cron
```

## More hardening
```
a2dismod status
```
```
nano /etc/apache2/conf-available/security.conf
```
```
[...]
ServerTokens Prod
[...]
ServerSignature Off
[...]
TraceEnable Off
[...]
```
```
systemctl restart php8.1-fpm.service redis-server.service apache2.service
```
Install fail2ban
```
apt install -y fail2ban ufw
```
```
touch /etc/fail2ban/filter.d/nextcloud.conf
```
```
cat <<EOF >/etc/fail2ban/filter.d/nextcloud.conf
[Definition]
_groupsre = (?:(?:,?\s*"\w+":(?:"[^"]+"|\w+))*)
failregex = ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Login failed:
            ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Trusted domain error.
datepattern = ,?\s*"time"\s*:\s*"%%Y-%%m-%%d[T ]%%H:%%M:%%S(%%z)?"
EOF
```

Now create a new jail file
```
nano /etc/fail2ban/jail.d/nextcloud.local
```
```
[nextcloud]
backend = auto
enabled = true
port = 80,443
protocol = tcp
filter = nextcloud
maxretry = 5
bantime = 3600
findtime = 36000
logpath = /var/log/nextcloud/nextcloud.log
```
```
service fail2ban restart
```

Activate the firewall and adjust the SSH port 22 if necessary

```
ufw allow 80/tcp comment "LetsEncrypt" && ufw allow 443/tcp comment "TLS" && ufw allow 22/tcp comment "SSH"
```
```
ufw logging medium
ufw enable
service ufw restart
```

# Nextcloud 21

```
apt install -y curl gnupg2 git lsb-release ssl-cert ca-certificates apt-transport-https tree locate software-properties-common dirmngr screen htop net-tools zip unzip bzip2 ffmpeg ghostscript libfile-fcntllock-perl libfontconfig1 libfuse2 socat
```

debian

```
apt install -y \
curl gnupg2 zip unzip
```

Mariadb
add repository
```sh
curl -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash
```
install
```
apt update && apt install -y mariadb-server
```
```
mysql_secure_installation
```
Configure Maria-DB
```
service mariadb stop && mv /etc/mysql/my.cnf /etc/mysql/my.cnf.bak && nano /etc/mysql/my.cnf
```
and fill it with the following content:
```sh
[client]
default-character-set = utf8mb4
port = 3306
socket = /var/run/mysqld/mysqld.sock
[mysqld_safe]
log_error = /var/log/mysql/mysql_error.log
nice = 0
socket = /var/run/mysqld/mysqld.sock
[mysqld]
basedir = /usr
bind-address = 127.0.0.1
binlog_format = ROW
bulk_insert_buffer_size = 16M
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
concurrent_insert = 2
connect_timeout = 5
datadir = /var/lib/mysql
default_storage_engine = InnoDB
expire_logs_days = 2
general_log_file = /var/log/mysql/mysql.log
general_log = 0
innodb_buffer_pool_size = 2G
innodb_buffer_pool_instances = 1
innodb_flush_log_at_trx_commit = 2
innodb_log_buffer_size = 32M
innodb_max_dirty_pages_pct = 90
innodb_file_per_table = 1
innodb_open_files = 400
innodb_io_capacity = 4000
innodb_flush_method = O_DIRECT
innodb_read_only_compressed=OFF
key_buffer_size = 128M
lc_messages_dir = /usr/share/mysql
lc_messages = en_US
log_bin = /var/log/mysql/mariadb-bin
log_bin_index = /var/log/mysql/mariadb-bin.index
log_error = /var/log/mysql/mysql_error.log
log_slow_verbosity = query_plan
log_warnings = 2
long_query_time = 1
max_allowed_packet = 16M
max_binlog_size = 100M
max_connections = 2000
max_heap_table_size = 64M
myisam_recover_options = BACKUP
myisam_sort_buffer_size = 512M
port = 3306
pid-file = /var/run/mysqld/mysqld.pid
query_cache_limit = 2M
query_cache_size = 64M
query_cache_type = 1
query_cache_min_res_unit = 2k
read_buffer_size = 2M
read_rnd_buffer_size = 1M
skip-external-locking
skip-name-resolve
slow_query_log_file = /var/log/mysql/mariadb-slow.log
slow-query-log = 1
socket = /var/run/mysqld/mysqld.sock
sort_buffer_size = 4M
table_open_cache = 400
thread_cache_size = 128
tmp_table_size = 64M
tmpdir = /tmp
transaction_isolation = READ-COMMITTED
#unix_socket=OFF
user = mysql
wait_timeout = 600
[mysqldump]
max_allowed_packet = 16M
quick
quote-names
[isamchk]
key_buffer = 16M
```
```
service mariadb restart
```
```bash
mysql -uroot -p -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci; CREATE USER nextcloud@localhost identified by 'nextcloud'; GRANT ALL PRIVILEGES on nextcloud.* to nextcloud@localhost; FLUSH privileges;"
```
**Redis-server**
```
apt install -y redis-server
```
```sh
cp /etc/redis/redis.conf /etc/redis/redis.conf.bak
sed -i 's/port 6379/port 0/' /etc/redis/redis.conf
sed -i s/\#\ unixsocket/\unixsocket/g /etc/redis/redis.conf
sed -i 's/unixsocketperm 700/unixsocketperm 770/' /etc/redis/redis.conf
sed -i 's/# maxclients 10000/maxclients 10240/' /etc/redis/redis.conf
usermod -aG redis www-data
cp /etc/sysctl.conf /etc/sysctl.conf.bak
sed -i '$avm.overcommit_memory = 1' /etc/sysctl.conf
```

## Apache2 customization

```
a2enmod rewrite headers env dir mime
nano /etc/apache2/mods-available/http2.conf
```
adjust
```
# mod_http2 doesn't work with mpm_prefork
<IfModule !mpm_prefork>
Protocols h2 h2c http/1.1
H2Direct on
H2StreamMaxMemSize 5120000000
[...]
```
```
systemctl restart apache2.service
```
```
cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/001-nextcloud.conf
```
```
a2dissite 000-default.conf
```
```
nano /etc/apache2/sites-available/001-nextcloud.conf
```
paste this replacing `yourdomain.com`

```
<VirtualHost *:80>
ServerName yourdomain.com
ServerAlias yourdomain.com
ServerAdmin mail@yourdomain.com
DocumentRoot /var/www/html/nextcloud
ErrorLog /var/log/apache2/error.log
CustomLog /var/log/apache2/access.log combined
RewriteEngine on
RewriteCond %{SERVER_NAME} =yourdomain.com
RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
```
activate vHost
```
a2ensite 001-nextcloud.conf && systemctl restart apache2.service
```

**Certbot**
```
apt install -y certbot python3-certbot-apache
certbot --apache
```
Nextcloud vHost: accept all lines and adjust values ​​to your system
```
mv /etc/apache2/sites-available/001-nextcloud-le-ssl.conf /etc/apache2/sites-available/001-nextcloud-le-ssl.conf.bak
```
```
nano /etc/apache2/sites-available/001-nextcloud-le-ssl.conf
```
```apache
<IfModule mod_ssl.c>
SSLUseStapling on
SSLStaplingCache shmcb:/var/run/ocsp(128000)
<VirtualHost *:443>
SSLCertificateFile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
SSLCACertificateFile /etc/letsencrypt/live/yourdomain.com/fullchain.pem
SSLCertificateKeyFile /etc/letsencrypt/live/yourdomain.com/privkey.pem
#######################################################################
# For self-signed-certificates only!
# SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
# SSLCACertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
# SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
#######################################################################
Protocols h2 h2c http/1.1
Header add Strict-Transport-Security: "max-age=15552000;includeSubdomains"
ServerAdmin mail@yourdomain.com
ServerName yourdomain.com
ServerAlias yourdomain.com
SSLEngine on
SSLCompression off
SSLOptions +StrictRequire
SSLProtocol -all +TLSv1.3 +TLSv1.2
SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
SSLHonorCipherOrder off
SSLSessionTickets off
ServerSignature off
SSLStaplingResponderTimeout 5
SSLStaplingReturnResponderErrors off
SSLOpenSSLConfCmd Curves X448:secp521r1:secp384r1:prime256v1
SSLOpenSSLConfCmd ECDHParameters secp384r1
LogLevel warn
CustomLog /var/log/apache2/access.log combined
ErrorLog /var/log/apache2/error.log
DocumentRoot /var/www/html/nextcloud
<Directory /var/www/html/nextcloud/>
Options Indexes FollowSymLinks
AllowOverride All
Require all granted
Satisfy Any
</Directory>
<IfModule mod_dav.c>
Dav off
</IfModule>
<Directory /var/nc_data/>
Require all denied
</Directory>
<Files ".ht*">
Require all denied
</Files>
TraceEnable off
RewriteEngine On
RewriteCond %{REQUEST_METHOD} ^TRACK
RewriteRule .* - [R=405,L]
SetEnv HOME /var/www/html/nextcloud
SetEnv HTTP_HOME /var/www/html/nextcloud
<IfModule mod_reqtimeout.c>
RequestReadTimeout body=0
</IfModule>
</VirtualHost>
</IfModule>
```
Expand and enable security

```
openssl dhparam -dsaparam -out /etc/ssl/certs/dhparam.pem 4096
cat /etc/ssl/certs/dhparam.pem >> /etc/letsencrypt/live/yourdomain.com/fullchain.pem
```
Editing the Apache2 configuration file:
```
nano /etc/apache2/apache2.conf
```
```apache
ServerName yourdomain.com
[...]
<Directory /var/www/>
Options FollowSymLinks MultiViews
AllowOverride All
Require all granted
</Directory>
```
```
systemctl restart apache2.service
```

**PHP 8**

```
echo "deb [arch=amd64] https://packages.sury.org/php/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/php.list
```
```
wget -qO - https://packages.sury.org/php/apt.gpg | apt-key add -
```

```sh
PHPVERSION="8.0"
apt install -y libapache2-mod-php$PHPVERSION php-common \
php$PHPVERSION-{fpm,gd,curl,xml,zip,intl,mbstring,bz2,ldap,apcu,bcmath,gmp,imagick,igbinary,mysql,redis,smbclient,cli,common,opcache,readline} \
imagemagick --allow-change-held-packages
```
Create backups of configuration files before modifying:
```sh
cp /etc/php/$PHPVERSION/fpm/pool.d/www.conf /etc/php/$PHPVERSION/fpm/pool.d/www.conf.bak
cp /etc/php/$PHPVERSION/fpm/php-fpm.conf /etc/php/$PHPVERSION/fpm/php-fpm.conf.bak
cp /etc/php/$PHPVERSION/cli/php.ini /etc/php/$PHPVERSION/cli/php.ini.bak
cp /etc/php/$PHPVERSION/fpm/php.ini /etc/php/$PHPVERSION/fpm/php.ini.bak
cp /etc/php/$PHPVERSION/fpm/php-fpm.conf /etc/php/$PHPVERSION/fpm/php-fpm.conf.bak
cp /etc/php/$PHPVERSION/mods-available/apcu.ini /etc/php/$PHPVERSION/mods-available/apcu.ini.bak
cp /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml.bak
```
Calculate some specific to your system parameters (just execute the following commands)
```sh
AvailableRAM=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
AverageFPM=$(ps --no-headers -o 'rss,cmd' -C php-fpm"$PHPVERSION" | awk '{ sum+=$1 } END { printf ("%d\n", sum/NR/1024,"M") }')
FPMS=$((AvailableRAM/AverageFPM))
PMaxSS=$((FPMS*2/3))
PMinSS=$((PMaxSS/2))
PStartS=$(((PMaxSS+PMinSS)/2))
```
```
YOURTIMEZONE="Europe\/\Kyiv/"
```
```sh
sed -i "s/;env\[HOSTNAME\] = /env[HOSTNAME] = /" /etc/php/$PHPVERSION/fpm/pool.d/www.conf
sed -i "s/;env\[TMP\] = /env[TMP] = /" /etc/php/$PHPVERSION/fpm/pool.d/www.conf
sed -i "s/;env\[TMPDIR\] = /env[TMPDIR] = /" /etc/php/$PHPVERSION/fpm/pool.d/www.conf
sed -i "s/;env\[TEMP\] = /env[TEMP] = /" /etc/php/$PHPVERSION/fpm/pool.d/www.conf
sed -i "s/;env\[PATH\] = /env[PATH] = /" /etc/php/$PHPVERSION/fpm/pool.d/www.conf
sed -i 's/pm.max_children =.*/pm.max_children = '$FPMS'/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
sed -i 's/pm.start_servers =.*/pm.start_servers = '$PStartS'/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
sed -i 's/pm.min_spare_servers =.*/pm.min_spare_servers = '$PMinSS'/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
sed -i 's/pm.max_spare_servers =.*/pm.max_spare_servers = '$PMaxSS'/' /etc/php/$PHPVERSION/fpm/pool.d/www.conf
sed -i "s/;pm.max_requests =.*/pm.max_requests = 1000/" /etc/php/$PHPVERSION/fpm/pool.d/www.conf
sed -i "s/allow_url_fopen =.*/allow_url_fopen = 1/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo.*/cgi.fix_pathinfo=1/" /etc/php/$PHPVERSION/fpm/php.ini

sed -i "s/output_buffering =.*/output_buffering = 'Off'/" /etc/php/$PHPVERSION/cli/php.ini
sed -i "s/max_execution_time =.*/max_execution_time = 3600/" /etc/php/$PHPVERSION/cli/php.ini
sed -i "s/max_input_time =.*/max_input_time = 3600/" /etc/php/$PHPVERSION/cli/php.ini
sed -i "s/post_max_size =.*/post_max_size = 10240M/" /etc/php/$PHPVERSION/cli/php.ini
sed -i "s/upload_max_filesize =.*/upload_max_filesize = 10240M/" /etc/php/$PHPVERSION/cli/php.ini
sed -i "s/;date.timezone.*/date.timezone = $YOURTIMEZONE" /etc/php/$PHPVERSION/cli/php.ini
sed -i "s/;cgi.fix_pathinfo.*/cgi.fix_pathinfo=1/" /etc/php/$PHPVERSION/cli/php.ini

sed -i "s/memory_limit = 128M/memory_limit = 1024M/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/output_buffering =.*/output_buffering = 'Off'/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/max_execution_time =.*/max_execution_time = 3600/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/max_input_time =.*/max_input_time = 3600/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/post_max_size =.*/post_max_size = 10240M/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/upload_max_filesize =.*/upload_max_filesize = 10240M/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = Europe\/\Berlin/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/;session.cookie_secure.*/session.cookie_secure = True/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/;opcache.enable=.*/opcache.enable=1/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/;opcache.enable_cli=.*/opcache.enable_cli=1/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/;opcache.memory_consumption=.*/opcache.memory_consumption=256/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=64/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=100000/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/;opcache.revalidate_freq=.*/opcache.revalidate_freq=1/" /etc/php/$PHPVERSION/fpm/php.ini
sed -i "s/;opcache.save_comments=.*/opcache.save_comments=1/" /etc/php/$PHPVERSION/fpm/php.ini

sed -i "s|;emergency_restart_threshold.*|emergency_restart_threshold = 10|g" /etc/php/$PHPVERSION/fpm/php-fpm.conf
sed -i "s|;emergency_restart_interval.*|emergency_restart_interval = 1m|g" /etc/php/$PHPVERSION/fpm/php-fpm.conf
sed -i "s|;process_control_timeout.*|process_control_timeout = 10|g" /etc/php/$PHPVERSION/fpm/php-fpm.conf

sed -i '$aapc.enable_cli=1' /etc/php/$PHPVERSION/mods-available/apcu.ini

sed -i "s/rights=\"none\" pattern=\"PS\"/rights=\"read|write\" pattern=\"PS\"/" /etc/ImageMagick-6/policy.xml
sed -i "s/rights=\"none\" pattern=\"EPS\"/rights=\"read|write\" pattern=\"EPS\"/" /etc/ImageMagick-6/policy.xml
sed -i "s/rights=\"none\" pattern=\"PDF\"/rights=\"read|write\" pattern=\"PDF\"/" /etc/ImageMagick-6/policy.xml
sed -i "s/rights=\"none\" pattern=\"XPS\"/rights=\"read|write\" pattern=\"XPS\"/" /etc/ImageMagick-6/policy.xml

sed -i '$a[mysql]' /etc/php/$PHPVERSION/mods-available/mysqli.ini
sed -i '$amysql.allow_local_infile=On' /etc/php/$PHPVERSION/mods-available/mysqli.ini
sed -i '$amysql.allow_persistent=On' /etc/php/$PHPVERSION/mods-available/mysqli.ini
sed -i '$amysql.cache_size=2000' /etc/php/$PHPVERSION/mods-available/mysqli.ini
sed -i '$amysql.max_persistent=-1' /etc/php/$PHPVERSION/mods-available/mysqli.ini
sed -i '$amysql.max_links=-1' /etc/php/$PHPVERSION/mods-available/mysqli.ini
sed -i '$amysql.default_port=3306' /etc/php/$PHPVERSION/mods-available/mysqli.ini
sed -i '$amysql.connect_timeout=60' /etc/php/$PHPVERSION/mods-available/mysqli.ini
sed -i '$amysql.trace_mode=Off' /etc/php/$PHPVERSION/mods-available/mysqli.ini
```
Restart services
```
systemctl restart php$PHPVERSION-fpm
a2dismod php$PHPVERSION && a2dismod mpm_prefork
a2enmod proxy_fcgi setenvif mpm_event http2
systemctl restart apache2.service
a2enconf php$PHPVERSION-fpm
systemctl restart apache2.service php$PHPVERSION-fpm
```


## Download Nextcloud 21
> If you want to download other version, replace `latest` with `nextcloud-21.0.9` to download **21.0.9** version for example
```sh
NCVERSION="nextcloud-21.0.9"
wget https://download.nextcloud.com/server/releases/$NCVERSION.zip
unzip $NCVERSION.zip && mv nextcloud/ /var/www/html/ && chown -R www-data:www-data /var/www/html/nextcloud && rm -f $NCVERSION.zip
```


## Installation of Nextcloud
> `Nextcloud-Admin` and `Nextcloud-Admin-Passswort` change to you own

```php
NC_ADMIN="NC_ADMIN"
NC_ADMIN_PASS="NC_ADMIN_PASS"
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:install --database "mysql" --database-name "nextcloud" --database-user "nextcloud" --database-pass "nextcloud" --admin-user "$NC_ADMIN" --admin-pass "$NC_ADMIN_PASS" --data-dir "/var/nc_data"
```
correct config.php – add the lines:
```
sudo -u www-data nano /var/www/html/nextcloud/config/config.php
```
```apache
[...]
),
'datadirectory' => '/var/nc_data',
'overwrite.cli.url' => 'https://yourdomain.com/',
'htaccess.RewriteBase' => '/',
[...]
```
Correct Nextcloud .htaccess
```sh
sudo -u www-data php /var/www/html/nextcloud/occ maintenance:update:htaccess
```
Nextcloud Customizations
```sh
mkdir -p /var/log/nextcloud/
chown -R www-data:www-data /var/log/nextcloud
sudo -u www-data cp /var/www/html/nextcloud/config/config.php /var/www/html/nextcloud/config/config.php.bak
sudo -u www-data sed -i 's/^[ ]*//' /var/www/html/nextcloud/config/config.php
sudo -u www-data sed -i '/);/d' /var/www/html/nextcloud/config/config.php
```
```sh
sudo -u www-data cat <<EOF >>/var/www/html/nextcloud/config/config.php
'activity_expire_days' => 14,
'allow_local_remote_servers' => true,
'auth.bruteforce.protection.enabled' => true,
'blacklisted_files' => 
array (
0 => '.htaccess',
1 => 'Thumbs.db',
2 => 'thumbs.db',
),
'cron_log' => true,
'default_phone_region' => 'DE',
'defaultapp' => 'files,dashboard',
'enable_previews' => true,
'enabledPreviewProviders' => 
array (
0 => 'OC\Preview\PNG',
1 => 'OC\Preview\JPEG',
2 => 'OC\Preview\GIF',
3 => 'OC\Preview\BMP',
4 => 'OC\Preview\XBitmap',
5 => 'OC\Preview\Movie',
6 => 'OC\Preview\PDF',
7 => 'OC\Preview\MP3',
8 => 'OC\Preview\TXT',
9 => 'OC\Preview\MarkDown',
),
'filesystem_check_changes' => 0,
'filelocking.enabled' => 'true',
'htaccess.RewriteBase' => '/',
'integrity.check.disabled' => false,
'knowledgebaseenabled' => false,
'logfile' => '/var/log/nextcloud/nextcloud.log',
'loglevel' => 2,
'logtimezone' => 'Europe/Kyiv',
'log_rotate_size' => '104857600',
'maintenance' => false,
'maintenance_window_start' => 1,
'memcache.local' => '\OC\Memcache\APCu',
'memcache.locking' => '\OC\Memcache\Redis',
'overwriteprotocol' => 'https',
'preview_max_x' => 1024,
'preview_max_y' => 768,
'preview_max_scale_factor' => 1,
'profile.enabled' => false,
'redis' => 
array (
'host' => '/var/run/redis/redis-server.sock',
'port' => 0,
'timeout' => 0.5,
'dbindex' => 1,
),
'quota_include_external_storage' => false,
'share_folder' => '/Freigaben',
'skeletondirectory' => '',
'theme' => '',
'trashbin_retention_obligation' => 'auto, 7',
'updater.release.channel' => 'stable',
);
EOF
```
```
sudo -u www-data php /var/www/html/nextcloud occ config:system:set remember_login_cookie_lifetime --value="1800"
sudo -u www-data php /var/www/html/nextcloud occ config:system:set simpleSignUpLink.shown --type=bool --value=false
sudo -u www-data php /var/www/html/nextcloud occ config:system:set versions_retention_obligation --value="auto, 365"
sudo -u www-data php /var/www/html/nextcloud occ config:system:set loglevel --value=2
sudo -u www-data php /var/www/html/nextcloud/occ config:system:set trusted_domains 1 --value=yourdomain.com
sudo -u www-data php /var/www/html/nextcloud/occ config:app:set settings profile_enabled_by_default --value="0"
```
Optional Nextcloud Office (~ 400MB)
```
sudo -u www-data /usr/bin/php /var/www/html/nextcloud/occ app:install richdocuments
sudo -u www-data /usr/bin/php /var/www/html/nextcloud/occ app:install richdocumentscode
a2enmod ssl && a2ensite 001-nextcloud.conf 001-nextcloud-le-ssl.conf
systemctl restart php$PHPVERSION-fpm.service redis-server.service apache2.service
```
## Cronjob
```
crontab -u www-data -e
```
```
*/5 * * * * php -f /var/www/html/nextcloud/cron.php > /dev/null 2>&1
```
save&exit

```
sudo -u www-data php /var/www/html/nextcloud/occ background:cron
```

## More hardening
```
a2dismod status
```
```
nano /etc/apache2/conf-available/security.conf
```
```
[...]
ServerTokens Prod
[...]
ServerSignature Off
[...]
TraceEnable Off
[...]
```
```
systemctl restart php$PHPVERSION-fpm.service redis-server.service apache2.service
```