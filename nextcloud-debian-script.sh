#!/bin/bash

# This is modified and simplified script from https://codeberg.org/criegerde/nextcloud-zero to install Nextcloud on Debian 11, other distro's not supported
# (Apache2, Redis, PHP, MariaDB)

# USER DATA:
# =============================================================================================================================
# =============================================================================================================================
# Nextcloud data directory (absolute path)
NC_DATA_DIR="/var/nc_data"

# Nextcloud release version ("latest.tar.bz2" or "nextcloud-21.0.9.tar.bz2" for example)
NC_RELEASE_VERSION="latest.tar.bz2"

# See Nextcloud system requirements 
# https://docs.nextcloud.com/server/{MAJOR_VERSION}/admin_manual/installation/system_requirements.html
# where {MAJOR_VERSION} can be "latest" or "21"
# For Nextcloud <= 23 version PHP 8.1 is not supported  

# PHP version (8.0 of 8.1)
PHP_VERSION="8.1"

# PHP max memory
PHP_MEM_SIZE="2048M"

# MariaDB version (10.5 or 10.6 etc.) You can check https://mariadb.com/kb/en/mariadb-server-release-dates/ for additional info
# It appears the latest LTS version 10.11 works fine with Nextcloud >= 21
MARIADB_VERSION="10.11"

# Your domain name for Nextcloud. For automatic LE sertificate you need proper CNAME entries 
NC_DOMAIN_NAME="yourdomain.com"

# Email address for Let's Encrypt
LE_MAIL="mail@example.com"

# MariaDB root password
#DB_ROOT_PASSWORD=""
# Or use generated
DB_ROOT_PASSWORD=$(openssl rand -hex 16)

# Nextcloud database user
DB_NC_USERNAME="ncdbuser"

# Nextcloud database password
#DB_NC_PASSWORD=""
# Or use generated
DB_NC_PASSWORD=$(openssl rand -hex 16)

# Local Nextcloud administrator
# any name, e.g.: "nc_admin"
NC_ADMIN_NAME="nc_admin"

# Password for the local Nextcloud administrator
#NC_ADMIN_PASSWORD="NeXtCLoUd-PwD"
# Or use generated
NC_ADMIN_PASSWORD=$(openssl rand -hex 16)

# Nextcloud Phone region
NC_PHONE_REGION='UA'

# PHP upload maximum size (0 for no limit)
MAX_UPLOAD_SIZE='20G'

# Password for Redis server
#REDIS_PASSWORD=""
# Or use generated
REDIS_PASSWORD=$(openssl rand -hex 16)

# Your timezone
TIME_ZONE='Europe/Kiev'

# =============================================================================================================================
# =============================================================================================================================
# END USER DATA

# MAIN LOGIC

###########################
#     Start time          #
###########################
start=$(date +%s)

# Identify the current user logged with
USER_NAME=$(logname)

# Check if user is root
if [ "$(id -u)" != "0" ]
then
clear
echo "*****************************"
echo "* PLEASE OPERATE AS ROOT!   *"
echo "*****************************"
exit 1
fi

# Ensure, admin software is available on the server
if [ -z "$(command -v lsb_release)" ]
then
apt install -y lsb-release
fi
if [ -z "$(command -v curl)" ]
then
apt install -y curl
fi
if [ -z "$(command -v wget)" ]
then
apt install -y wget
fi
if [ -z "$(command -v ping)" ]
then
apt install -y iputils-ping net-tools
fi

# Check system requirements
if [ ! "$(lsb_release -r | awk '{ print $2 }')" = "11" ]
then
clear
echo ""
echo "******************************************************"
echo "* You aren't operating on Debian 11 *"
echo "******************************************************"
echo ""
exit 1
fi

###########################
#     Uninstall-Script    #
###########################
mkdir -p /home/"$USER_NAME"/Nextcloud-Installationsskript/
touch /home/"$USER_NAME"/Nextcloud-Installationsskript/uninstall.sh
cat <<EOF >/home/"$USER_NAME"/Nextcloud-Installationsskript/uninstall.sh
#!/bin/bash
if [ "\$(id -u)" != "0" ]
then
clear
echo ""
echo "*****************************"
echo "* PLEASE OPERATE AS ROOT!   *"
echo "*****************************"
echo ""
exit 1
fi
clear
echo "*************************************************************************************"
echo "*                        WARNING!                                                   *"
echo "*                                                                                   *"
echo "* Nextcloud as well as ALL user files will be IRREVERSIBLY REMOVED from the system! *"
echo "*                                                                                   *"
echo "*************************************************************************************"
echo
echo "Press Ctrl+C To Abort"
echo
seconds=$((10))
while [ \$seconds -gt 0 ]; do
   echo -ne "Removal begins after: \$seconds\033[0K\r"
   sleep 1
   : \$((seconds--))
done
rm -Rf $NC_DATA_DIR
mv /etc/hosts.bak /etc/hosts
apt remove --purge --allow-change-held-packages -y nginx* php* mariadb-* mysql-common libdbd-mariadb-perl galera-* postgresql-* redis* fail2ban ufw apache2
rm -Rf /etc/ufw /etc/fail2ban /var/www /etc/mysql /etc/apache2 /etc/postgresql /etc/postgresql-common /var/lib/mysql /var/lib/postgresql /etc/letsencrypt /var/log/nextcloud /home/$USER_NAME/Nextcloud-Installationsskript/install.log /home/$USER_NAME/Nextcloud-Installationsskript/update.sh
rm -Rf /etc/nginx /usr/share/keyrings/nginx-archive-keyring.gpg /usr/share/keyrings/postgresql-archive-keyring.gpg
add-apt-repository ppa:ondrej/php -ry
rm -f /etc/ssl/certs/dhparam.pem /etc/apt/sources.list.d/* /etc/motd /root/.bash_aliases
deluser --remove-all-files acmeuser
crontab -u www-data -r
rm -f /etc/sudoers.d/acmeuser
apt autoremove -y
apt autoclean -y
sed -i '/vm.overcommit_memory = 1/d' /etc/sysctl.conf
echo ""
echo "Done!"
exit 0
EOF
chmod +x /home/"$USER_NAME"/Nextcloud-Installationsskript/uninstall.sh

##########################
#   Prevent Second Run   #
##########################
if [ -e "/var/www/nextcloud/config/config.php" ] || [ -e /etc/apache2/sites-available/001-nextcloud.conf ]; then
  clear
  echo "*************************************************"
  echo "* Test: Previous installation ......:::::FAILED *"
  echo "*************************************************"
  echo ""
  echo "* Nextcloud has already been installed on this system!"
  echo ""
  echo "* Please remove it completely before proceeding to a new installation."
  echo ""
  echo "* Please find the uninstall script here:"
  echo "* /home/$USER_NAME/Nextcloud-Installationsskript/uninstall.sh"
  echo ""
  exit 1
fi

###########################
#   Verify homedirectory  #
###########################
if [ ! -d "/home/$USER_NAME/" ]; then
  mkdir -p /home/"$USER_NAME"/
  else
  echo ""
fi
if [ ! -d "/home/$USER_NAME/Nextcloud-Installationsskript/" ]; then
  mkdir /home/"$USER_NAME"/Nextcloud-Installationsskript/
fi

###########################
#    System patches       #
###########################
apt=$(command -v apt-get)
aptmark=$(command -v apt-mark)
cat=$(command -v cat)
chmod=$(command -v chmod)
chown=$(command -v chown)
clear=$(command -v clear)
cp=$(command -v cp)
curl=$(command -v curl)
date=$(command -v date)
echo=$(command -v echo)
ln=$(command -v ln)
mkdir=$(command -v mkdir)
mv=$(command -v mv)
rm=$(command -v rm)
sed=$(command -v sed)
service=$(command -v service)
sudo=$(command -v sudo)
systemctl=$(command -v systemctl)
tar=$(command -v tar)
timedatectl=$(command -v timedatectl)
touch=$(command -v touch)
usermod=$(command -v usermod)
wget=$(command -v wget)

###########################
#        Timezone         #
###########################
timedatectl set-timezone "$TIME_ZONE"

###########################
#    System settings      #
###########################
${apt} install -y figlet
figlet=$(command -v figlet)
${touch} /etc/motd
${figlet} Nextcloud > /etc/motd
${cat} <<EOF >> /etc/motd

      (c) Keep Control IT-Services
      https://www.keep-control.net

EOF

###########################
#    Identify local ip    #
###########################
IPA=$(hostname -I | awk '{print $1}')

###########################
# Logfile install.log     #
###########################
exec > >(tee -i "/home/$USER_NAME/Nextcloud-Installationsskript/install.log")
exec 2>&1

###########################
#    NC data index        #
###########################
function nextcloud_scan_data() {
  ${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ files:scan --all
  ${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ files:scan-app-data
  ${service} fail2ban restart
  }

###########################
#   Cosmetical function   #
###########################
CrI() {
  while ps "$!" > /dev/null; do
  echo -n '.'
  sleep '0.5'
  done
  ${echo} ''
  }

###########################
#    Update-function      #
###########################
function update_and_clean() {
  ${apt} update
  ${apt} upgrade -y
  ${apt} autoclean -y
  ${apt} autoremove -y
  }

###########################
#    Restart services     #
###########################
function restart_all_services() {
  ${service} apache2 restart
  ${service} mariadb restart
  ${service} redis-server restart
  ${service} php$PHP_VERSION-fpm restart
  }

###########################
#    Relevant software    #
#    will be blocked for  #
#    apt                  #
###########################
function setHOLD() {
  ${aptmark} hold apache2*
  ${aptmark} hold redis*
  ${aptmark} hold mariadb*
  ${aptmark} hold mysql*
  ${aptmark} hold php*
  }

###########################
#    Required software    #
###########################
${apt} upgrade -y
${apt} install -y \
apt-transport-https bash-completion bzip2 ca-certificates cron dialog dirmngr ffmpeg ghostscript gpg gnupg gnupg2 htop jq \
libfile-fcntllock-perl libfontconfig1 libfuse2 locate net-tools rsyslog screen smbclient socat software-properties-common \
ssl-cert tree unzip wget zip debian-archive-keyring debian-keyring

###########################
#     Energy mode: off    #
###########################
${systemctl} mask sleep.target suspend.target hibernate.target hybrid-sleep.target

###########################
#   PHP 8 Repositories    #
###########################
${curl} -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/packages.sury.org.gpg
${echo} "deb [signed-by=/etc/apt/trusted.gpg.d/packages.sury.org.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

###########################
#     DB Repositories     #
###########################
${curl} -sS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-$MARIADB_VERSION"

###########################
#  Remove unatt.upgrades  #
###########################
${apt} purge -y unattended-upgrades

###########################
#      System update      #
###########################
update_and_clean

###########################
#         Clean Up        #
###########################
${apt} remove -y apache2 nginx nginx-common nginx-full --allow-change-held-packages
${rm} -Rf /etc/apache2 /etc/nginx

###########################
#     Installation:       #
# PHP, Redis, MariaDB,    #
# Certbot, Fail2ban, UFW  #
###########################
${apt} install -y libapache2-mod-php$PHP_VERSION php-common \
php$PHP_VERSION-{fpm,gd,curl,xml,zip,intl,mbstring,bz2,ldap,apcu,bcmath,gmp,imagick,igbinary,mysql,redis,smbclient,cli,common,opcache,readline} imagemagick \
redis-server \
mariadb-server \
certbot python3-certbot-apache \
fail2ban \
ufw --allow-change-held-packages

###########################
#    Create directories   #
###########################
${mkdir} -p /var/log/nextcloud
${chown} -R www-data:www-data /var/log/nextcloud /var/www/

###########################
#    PHP customization    #
###########################
${cp} /etc/php/$PHP_VERSION/fpm/pool.d/www.conf /etc/php/$PHP_VERSION/fpm/pool.d/www.conf.bak
${cp} /etc/php/$PHP_VERSION/fpm/php-fpm.conf /etc/php/$PHP_VERSION/fpm/php-fpm.conf.bak
${cp} /etc/php/$PHP_VERSION/cli/php.ini /etc/php/$PHP_VERSION/cli/php.ini.bak
${cp} /etc/php/$PHP_VERSION/fpm/php.ini /etc/php/$PHP_VERSION/fpm/php.ini.bak
${cp} /etc/php/$PHP_VERSION/mods-available/apcu.ini /etc/php/$PHP_VERSION/mods-available/apcu.ini.bak
${cp} /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml.bak
${cp} /etc/php/$PHP_VERSION/mods-available/mysqli.ini /etc/php/$PHP_VERSION/mods-available/mysqli.ini.bak
AvailableRAM=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
AverageFPM=$(ps --no-headers -o 'rss,cmd' -C php-fpm$PHP_VERSION | awk '{ sum+=$1 } END { printf ("%d\n", sum/NR/1024,"M") }')
FPMS=$((AvailableRAM/AverageFPM))
PMaxSS=$((FPMS*2/3))
PMinSS=$((PMaxSS/2))
PStartS=$(((PMaxSS+PMinSS)/2))
${sed} -i '
  s/;env\[HOSTNAME\] = /env[HOSTNAME] = /
  s/;env\[TMP\] = /env[TMP] = /
  s/;env\[TMPDIR\] = /env[TMPDIR] = /
  s/;env\[TEMP\] = /env[TEMP] = /
  s/;env\[PATH\] = /env[PATH] = /
  s/pm.max_children =.*/pm.max_children = '$FPMS'/
  s/pm.start_servers =.*/pm.start_servers = '$PStartS'/
  s/pm.min_spare_servers =.*/pm.min_spare_servers = '$PMinSS'/
  s/pm.max_spare_servers =.*/pm.max_spare_servers = '$PMaxSS'/
  s/;pm.max_requests =.*/pm.max_requests = 1000/
' /etc/php/$PHP_VERSION/fpm/pool.d/www.conf
${sed} -i '
  s/allow_url_fopen =.*/allow_url_fopen = 1/
  s/;cgi.fix_pathinfo.*/cgi.fix_pathinfo=1/
  s/memory_limit = 128M/memory_limit = '$PHP_MEM_SIZE'/
  s/output_buffering =.*/output_buffering = 'Off'/
  s/max_execution_time =.*/max_execution_time = 3600/
  s/max_input_time =.*/max_input_time = 3600/
  s/post_max_size =.*/post_max_size = 10240M/
  s/upload_max_filesize =.*/upload_max_filesize = '$MAX_UPLOAD_SIZE'/
  s|;date.timezone.*|date.timezone = '$TIME_ZONE'|
  s/;session.cookie_secure.*/session.cookie_secure = True/
  s/;opcache.enable=.*/opcache.enable=1/
  s/;opcache.enable_cli=.*/opcache.enable_cli=1/
  s/;opcache.memory_consumption=.*/opcache.memory_consumption=256/
  s/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=64/
  s/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=100000/
  s/;opcache.revalidate_freq=.*/opcache.revalidate_freq=1/
  s/;opcache.save_comments=.*/opcache.save_comments=1/
' /etc/php/$PHP_VERSION/fpm/php.ini
${sed} -i '
  s/output_buffering =.*/output_buffering = 'Off'/
  s/max_execution_time =.*/max_execution_time = 3600/
  s/max_input_time =.*/max_input_time = 3600/
  s/post_max_size =.*/post_max_size = 10240M/
  s/upload_max_filesize =.*/upload_max_filesize = '$MAX_UPLOAD_SIZE'/
  s|;date.timezone.*|date.timezone = '$TIME_ZONE'|
  s/;cgi.fix_pathinfo.*/cgi.fix_pathinfo=1/
' /etc/php/$PHP_VERSION/cli/php.ini
${sed} -i '
  s|;emergency_restart_threshold.*|emergency_restart_threshold = 10|g
  s|;emergency_restart_interval.*|emergency_restart_interval = 1m|g
  s|;process_control_timeout.*|process_control_timeout = 10|g
' /etc/php/$PHP_VERSION/fpm/php-fpm.conf
${sed} -i '
  $aapc.enable_cli=1
' /etc/php/$PHP_VERSION/mods-available/apcu.ini
${sed} -i '
  s/rights=\"none\" pattern=\"PS\"/rights=\"read|write\" pattern=\"PS\"/
  s/rights=\"none\" pattern=\"EPS\"/rights=\"read|write\" pattern=\"EPS\"/
  s/rights=\"none\" pattern=\"PDF\"/rights=\"read|write\" pattern=\"PDF\"/
  s/rights=\"none\" pattern=\"XPS\"/rights=\"read|write\" pattern=\"XPS\"/
' /etc/ImageMagick-6/policy.xml
${sed} -i '
  $a[mysql]
  $amysql.allow_local_infile=On
  $amysql.allow_persistent=On
  $amysql.cache_size=2000
  $amysql.max_persistent=-1
  $amysql.max_links=-1
  $amysql.default_port=3306
  $amysql.connect_timeout=60
  $amysql.trace_mode=Off
' /etc/php/$PHP_VERSION/mods-available/mysqli.ini
if [ ! -e "/usr/bin/gs" ]; then
${ln} -s /usr/local/bin/gs /usr/bin/gs
fi

###########################
#        Restart PHP      #
###########################
${systemctl} restart php$PHP_VERSION-fpm
a2dismod php$PHP_VERSION && a2dismod mpm_prefork
a2enmod proxy_fcgi setenvif mpm_event http2
${systemctl} restart apache2.service
a2enconf php$PHP_VERSION-fpm
${systemctl} restart apache2.service php$PHP_VERSION-fpm

###########################
#   Redis customization   #
###########################
${cp} /etc/redis/redis.conf /etc/redis/redis.conf.bak
${sed} -i \
"s/port 6379/port 0/;
s|# unixsocket|unixsocket|g;
s/unixsocketperm 700/unixsocketperm 770/;
s/# requirepass foobared/requirepass $REDIS_PASSWORD/;
s/# maxclients 10000/maxclients 10240/;" \
/etc/redis/redis.conf
${usermod}  -aG redis www-data
${cp} /etc/sysctl.conf /etc/sysctl.conf.bak
${sed} -i '$avm.overcommit_memory = 1' /etc/sysctl.conf
sysctl -p

###########################
#  Apache2 customization  #
###########################
a2enmod rewrite headers env dir mime
${sed} -i '/<IfModule !mpm_prefork>/,/<\/IfModule>/ {
    /Protocols h2 h2c http\/1\.1/ a \
    H2Direct on \
    H2StreamMaxMemSize 5120000000
}' /etc/apache2/mods-available/http2.conf
${systemctl} restart apache2.service
${cp} /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/001-nextcloud.conf
a2dissite 000-default.conf
${touch} /etc/apache2/sites-available/001-nextcloud.conf
${cat} <<EOF >/etc/apache2/sites-available/001-nextcloud.conf
<VirtualHost *:80>
ServerName $NC_DOMAIN_NAME
ServerAlias $NC_DOMAIN_NAME
ServerAdmin mail@$NC_DOMAIN_NAME
DocumentRoot /var/www/nextcloud
ErrorLog /var/log/apache2/error.log
CustomLog /var/log/apache2/access.log combined
RewriteEngine on
RewriteCond %{SERVER_NAME} =$NC_DOMAIN_NAME
RewriteRule ^ https://%{SERVER_NAME}%{REQUEST_URI} [END,NE,R=permanent]
</VirtualHost>
EOF
a2ensite 001-nextcloud.conf && ${systemctl} restart apache2.service

###########################
#  MariaDB customization  #
###########################
${systemctl} stop mariadb && ${mv} /etc/mysql/my.cnf /etc/mysql/my.cnf.bak
${touch} /etc/mysql/my.cnf && ${cat} <<EOF >/etc/mysql/my.cnf
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
EOF
${systemctl} restart mariadb
mysql -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -e "CREATE USER ${DB_NC_USERNAME}@localhost IDENTIFIED BY '${DB_NC_PASSWORD}';"
mysql -e "GRANT ALL PRIVILEGES ON nextcloud.* TO '${DB_NC_USERNAME}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"
mysql_secure_installation=$(command -v mysql_secure_installation)
${cat} <<EOF | ${mysql_secure_installation}
\n
n
y
y
y
y
EOF
mysql -u root -e "SET PASSWORD FOR root@'localhost' = PASSWORD('$DB_ROOT_PASSWORD'); FLUSH PRIVILEGES;"

###########################
#          Certbot        #
###########################
certbot --apache --non-interactive --agree-tos --email $LE_MAIL -d $NC_DOMAIN_NAME
${mv} /etc/apache2/sites-available/001-nextcloud-le-ssl.conf /etc/apache2/sites-available/001-nextcloud-le-ssl.conf.bak
${touch} /etc/apache2/sites-available/001-nextcloud-le-ssl.conf && ${cat} <<EOF >/etc/apache2/sites-available/001-nextcloud-le-ssl.conf
<IfModule mod_ssl.c>
SSLUseStapling on
SSLStaplingCache shmcb:/var/run/ocsp(128000)
<VirtualHost *:443>
SSLCertificateFile /etc/letsencrypt/live/$NC_DOMAIN_NAME/fullchain.pem
SSLCACertificateFile /etc/letsencrypt/live/$NC_DOMAIN_NAME/fullchain.pem
SSLCertificateKeyFile /etc/letsencrypt/live/$NC_DOMAIN_NAME/privkey.pem
#######################################################################
# For self-signed-certificates only!
# SSLCertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
# SSLCACertificateFile /etc/ssl/certs/ssl-cert-snakeoil.pem
# SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
#######################################################################
Protocols h2 h2c http/1.1
Header add Strict-Transport-Security: "max-age=15552000;includeSubdomains"
ServerAdmin mail@$NC_DOMAIN_NAME
ServerName $NC_DOMAIN_NAME
ServerAlias $NC_DOMAIN_NAME
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
DocumentRoot /var/www/nextcloud
<Directory /var/www/nextcloud/>
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
SetEnv HOME /var/www/nextcloud
SetEnv HTTP_HOME /var/www/nextcloud
<IfModule mod_reqtimeout.c>
RequestReadTimeout body=0
</IfModule>
</VirtualHost>
</IfModule>
EOF
openssl dhparam -dsaparam -out /etc/ssl/certs/dhparam.pem 4096
${cat} /etc/ssl/certs/dhparam.pem >> /etc/letsencrypt/live/$NC_DOMAIN_NAME/fullchain.pem
${sed} -i "1s/^/ServerName $NC_DOMAIN_NAME\n/; \
/<Directory \/var\/www\/>/,/<\/Directory>/ {
    s/Options Indexes FollowSymLinks/Options FollowSymLinks MultiViews/
    s/AllowOverride None/AllowOverride All/
};" /etc/apache2/apache2.conf
${systemctl} restart apache2.service

###########################
#    Download Nextcloud   #
###########################
${echo} "Downloading:" $NC_RELEASE_VERSION
${wget} -q https://download.nextcloud.com/server/releases/$NC_RELEASE_VERSION & CrI
${wget} -q https://download.nextcloud.com/server/releases/$NC_RELEASE_VERSION.md5
${echo} ""
${echo} "Verify Checksum (MD5):"
if [ "$(md5sum -c $NC_RELEASE_VERSION.md5 < $NC_RELEASE_VERSION | awk '{ print $2 }')" = "OK" ]
then
md5sum -c $NC_RELEASE_VERSION.md5 < $NC_RELEASE_VERSION
${echo} ""
else
${echo} ""
${echo} "CHECKSUM ERROR => SECURITY ALERT"
exit 1
fi
${echo} "Extracting:" $NC_RELEASE_VERSION
${tar} -xjf $NC_RELEASE_VERSION -C /var/www & CrI
${chown} -R www-data:www-data /var/www/
${rm} -f $NC_RELEASE_VERSION $NC_RELEASE_VERSION.md5
restart_all_services

###########################
# Nextcloud Installation  #
###########################
if [[ ! -e $NC_DATA_DIR ]];
then
${mkdir} -p $NC_DATA_DIR
fi
${chown} -R www-data:www-data $NC_DATA_DIR
${echo} "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${echo} ""
${echo} "Your Nextcloud will now be installed silently - please be patient!"
${echo} ""
sudo -u www-data php /var/www/nextcloud/occ maintenance:install --database "mysql" --database-name "nextcloud" --database-user "${DB_NC_USERNAME}" --database-pass "${DB_NC_PASSWORD}" --admin-user "${NC_ADMIN_NAME}" --admin-pass "${NC_ADMIN_PASSWORD}" --data-dir "${NC_DATA_DIR}"
${echo} ""
#sleep 5
declare -l YOURSERVERNAME
YOURSERVERNAME=$(hostname)
${sudo} -u www-data ${cp} /var/www/nextcloud/config/config.php /var/www/nextcloud/config/config.php.bak
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set trusted_domains 0 --value="$YOURSERVERNAME"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set trusted_domains 1 --value="$NC_DOMAIN_NAME"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set trusted_domains 2 --value="$IPA"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set overwrite.cli.url --value=https://"$NC_DOMAIN_NAME"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set overwritehost --value="$NC_DOMAIN_NAME"
${cp} /var/www/nextcloud/.user.ini /usr/local/src/.user.ini.bak
${sudo} -u www-data ${sed} -i 's/output_buffering=.*/output_buffering=0/' /var/www/nextcloud/.user.ini
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ background:cron
${sudo} -u www-data ${touch} /var/www/nextcloud/config/tweaks.config.php
${cat} <<EOF >>/var/www/nextcloud/config/tweaks.config.php
<?php
\$CONFIG = array (
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
    'default_phone_region' => '$NC_PHONE_REGION',
    'enable_previews' => true,
    'enabledPreviewProviders' =>
    array (
      0 => 'OC\\Preview\\PNG',
      1 => 'OC\\Preview\\JPEG',
      2 => 'OC\\Preview\\GIF',
      3 => 'OC\\Preview\\BMP',
      4 => 'OC\\Preview\\XBitmap',
      5 => 'OC\\Preview\\Movie',
      6 => 'OC\\Preview\\PDF',
      7 => 'OC\\Preview\\MP3',
      8 => 'OC\\Preview\\TXT',
      9 => 'OC\\Preview\\MarkDown',
      ),
      'filesystem_check_changes' => 0,
      'filelocking.enabled' => 'true',
      'htaccess.RewriteBase' => '/',
      'integrity.check.disabled' => false,
      'knowledgebaseenabled' => false,
      'log_rotate_size' => '104857600',
      'logfile' => '/var/log/nextcloud/nextcloud.log',
      'loglevel' => 2,
      'logtimezone' => '$TIME_ZONE',
      'memcache.local' => '\\OC\\Memcache\\APCu',
      'memcache.locking' => '\\OC\\Memcache\\Redis',
      'overwriteprotocol' => 'https',
      'preview_max_x' => 1024,
      'preview_max_y' => 768,
      'preview_max_scale_factor' => 1,
      'profile.enabled' => false,
      'redis' =>
      array (
        'host' => '/var/run/redis/redis-server.sock',
        'port' => 0,
        'password' => '$REDIS_PASSWORD',
        'timeout' => 0.5,
        'dbindex' => 1,
        ),
        'quota_include_external_storage' => false,
        'share_folder' => '/Releases',
        'skeletondirectory' => '',
        'trashbin_retention_obligation' => 'auto, 7',
        );
EOF
${sed} -i 's/^[ ]*//' /var/www/nextcloud/config/config.php

###########################
# Nextcloud Permissions   #
###########################
${chown} -R www-data:www-data /var/www

###########################
#      Nextcloud-CRON     #
###########################
(/usr/bin/crontab -u www-data -l ; echo "*/5 * * * * /usr/bin/php -f /var/www/nextcloud/cron.php > /dev/null 2>&1") | /usr/bin/crontab -u www-data -

###########################
# Installation fail2ban   #
###########################
${touch} /etc/fail2ban/filter.d/nextcloud.conf
${cat} <<EOF >/etc/fail2ban/filter.d/nextcloud.conf
[Definition]
_groupsre = (?:(?:,?\s*"\w+":(?:"[^"]+"|\w+))*)
failregex = ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Login failed:
            ^\{%(_groupsre)s,?\s*"remoteAddr":"<HOST>"%(_groupsre)s,?\s*"message":"Trusted domain error.
datepattern = ,?\s*"time"\s*:\s*"%%Y-%%m-%%d[T ]%%H:%%M:%%S(%%z)?"
EOF
${touch} /etc/fail2ban/jail.d/nextcloud.local
${cat} <<EOF >/etc/fail2ban/jail.d/nextcloud.local
[DEFAULT]
maxretry=3
bantime=1800
findtime = 1800
[nextcloud]
backend = auto
enabled = true
port = 80,443
protocol = tcp
filter = nextcloud
maxretry = 5
logpath = /var/log/nextcloud/nextcloud.log
[nginx-http-auth]
enabled = true
EOF

###########################
# Installation ufw        #
###########################
ufw=$(command -v ufw)
${ufw} allow 80/tcp comment "LetsEncrypt(http)"
${ufw} allow 443/tcp comment "TLS(https)"
SSHPORT=$(grep -w Port /etc/ssh/sshd_config | awk '/Port/ {print $2}')
${ufw} allow "$SSHPORT"/tcp comment "SSH"
${ufw} logging medium && ${ufw} default deny incoming
${cat} <<EOF | ${ufw} enable
y
EOF
${service} redis-server restart
${service} ufw restart
${systemctl} enable fail2ban.service
${service} fail2ban restart

###########################
#  Nextcloud customizing  #
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:disable survey_client
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:disable firstrunwizard
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:disable federation
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:disable support
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:app:set settings profile_enabled_by_default --value="0"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:enable admin_audit
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:enable files_pdfviewer
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:enable contacts
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:enable calendar
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:enable groupfolders
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:install richdocuments
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ app:install richdocumentscode
rediscli=$(command -v redis-cli)
${rediscli} -s /var/run/redis/redis-server.sock <<EOF
FLUSHALL
quit
EOF
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ db:add-missing-primary-keys
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set versions_retention_obligation --value="auto, 365"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set simpleSignUpLink.shown --type=bool --value=false
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:system:set remember_login_cookie_lifetime --value="1800"
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ db:add-missing-indices
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ db:add-missing-columns
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ db:convert-filecache-bigint
${sudo} -u www-data /usr/bin/php /var/www/nextcloud/occ config:app:set settings profile_enabled_by_default --value="0"
nextcloud_scan_data
a2enmod ssl && a2ensite 001-nextcloud.conf 001-nextcloud-le-ssl.conf
${systemctl} restart php$PHP_VERSION-fpm.service redis-server.service apache2.service
${echo} ""
${echo} "System optimizations"
${echo} ""
${echo} "It will take a few minutes - please be patient!"
${echo} ""
${sudo} -u www-data /usr/bin/php -f /var/www/nextcloud/cron.php & CrI

###########################
#      More hardening     #
###########################
a2dismod status
${sed} -i -E \
"s/ServerTokens OS/ServerTokens Prod/;
s/ServerSignature On/ServerSignature Off/;" \
/etc/apache2/conf-available/security.conf
${systemctl} restart php$PHP_VERSION-fpm.service redis-server.service apache2.service
###########################
#      Hold Software      #
###########################
setHOLD

###########################
#          Restart        #
###########################
restart_all_services

###########################
# E: Final screen         #
###########################
${clear}
${echo} "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${echo} ""
${echo} "Server - IP(v4):"
${echo} "----------------"
${echo} "$IPA"
${echo} ""
${echo} "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${echo} ""
${echo} "Nextcloud:"
${echo} ""
${echo} "https://$NC_DOMAIN_NAME oder/or https://$IPA"
${echo} ""
${echo} "*******************************************************************************"
${echo} ""
${echo} "Nextcloud User/Pwd: $NC_ADMIN_NAME // $NC_ADMIN_PASSWORD"
${echo} ""
${echo} "Passwordreset     : nocc user:resetpassword $NC_ADMIN_NAME"
${echo} "                    <exit> and re-login <sudo -s> first, then <nocc> will work!"
${echo} ""
${echo} "Nextcloud datapath: $NC_DATA_DIR"
${echo} ""
${echo} "Nextcloud DB      : nextcloud"
${echo} "Nextcloud DB-User : $DB_NC_USERNAME / $DB_NC_PASSWORD"
${echo} ""
${echo} "MariaDB-Rootpwd   : $DB_ROOT_PASSWORD"
${echo} ""
${echo} "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${echo} ""

###########################
# Nextcloud-Log           #
###########################
${rm} -f /var/log/nextcloud/nextcloud.log
${sudo} -u www-data ${touch} /var/log/nextcloud/nextcloud.log

###########################
# occ Aliases (nocc)      #
###########################
if [ ! -f /root/.bashrc ]; then touch /root/.bashrc; fi
cat <<EOF >> /root/.bashrc
alias nocc="sudo -u www-data php /var/www/nextcloud/occ"
EOF
source /root/.bashrc

###########################
#         Clean Up        #
###########################
${cat} /dev/null > ~/.bash_history && history -c && history -w

###########################
# Calculating runtime     #
###########################
${echo} ""
end=$(date +%s)
runtime=$((end-start))
echo ""
if [ "$runtime" -lt 60 ] || [ $runtime -ge "120" ]; then
echo "Installation process completed in $((runtime/60)) minutes and $((runtime%60)) seconds."
else
echo "Installation process completed in $((runtime/60)) minute and $((runtime%60)) seconds."
echo ""
fi
${echo} "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
${echo} ""
exit 0