# Zabbix 6 nginx postgres

https://www.zabbix.com/download?zabbix=6.2&os_distribution=debian&os_version=11&components=server_frontend_agent&db=pgsql&ws=nginx

Follow the instructions

## Install Zabbix repository

```bash
wget https://repo.zabbix.com/zabbix/6.2/debian/pool/main/z/zabbix-release/zabbix-release_6.2-4%2Bdebian11_all.deb
sudo dpkg -i zabbix-release_6.2-4+debian11_all.deb
sudo apt update
```

## Install go for zabbix-agent2
doc - https://go.dev/doc/install

```
wget https://go.dev/dl/go1.19.3.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.19.3.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

```

## Install Zabbix server, frontend, agent

```bash
sudo apt install zabbix-server-pgsql zabbix-frontend-php php7.4-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-agent2
```

## Create initial database

```bash
sudo -u postgres createuser --pwprompt zabbix
```
```
sudo -u postgres createdb -O zabbix zabbix
```

## import initial schema and data

```bash
zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | sudo -u zabbix psql zabbix
```
```bash
echo "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;" | sudo -u postgres psql zabbix
```

```bash
cat /usr/share/zabbix-sql-scripts/postgresql/timescaledb.sql | sudo -u zabbix psql zabbix
```

## Configure the database for Zabbix server

```bash
sudo nano /etc/zabbix/zabbix_server.conf
```

contents:

```conf
DBPassword=password
```

## Configure PHP for Zabbix frontend
Edit file by uncomment and set `listen` and `server_name` directives and set as your values:

```bash
sudo nano /etc/zabbix/nginx.conf
```

contents:

```conf
listen 8080;
server_name example.com;
```

## Start Zabbix server and agent processes
```
sudo systemctl restart zabbix-server zabbix-agent2 nginx php7.4-fpm
sudo systemctl enable zabbix-server zabbix-agent2 nginx php7.4-fpm
```

## Recommend to regenerate locales
and selec the en_US.utf8 locale.
```bash
sudo dpkg-reconfigure locales
sudo apt autoremove
```