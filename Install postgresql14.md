source - https://www.postgresql.org/download/linux/debian/

# Create the file repository configuration:
```bash
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
```

# Import the repository signing key:
```bash
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
```

# Update the package lists:
```bash
sudo apt-get update
```

# Install the latest version of PostgreSQL.
# If you want a specific version, use `postgresql-12` or similar instead of `postgresql`:
```bash
sudo apt-get -y install postgresql-14
```

# Change data directory to new disk

## Locate data directory

```bash
sudo -u postgres psql
```

```sql
SHOW data_directory;
```

example output
```sql
       data_directory
-----------------------------
 /var/lib/postgresql/14/main
(1 row)

```
(exit psql shell - `\q`)

## Stop postgresql service

```bash
sudo systemctl stop postgresql
```
(verify that is stopped)
```
sudo systemctl status postgresql
```

## Copy existing data to new directory

```bash
sudo rsync -av /var/lib/postgresql /mnt/disks/db
```

## backup old directory just in case

```bash
sudo mv /var/lib/postgresql/14/main /var/lib/postgresql/14/main.bak
```

## Change settings in config file

```bash
sudo nano /etc/postgresql/14/main/postgresql.conf
```
search `data_directory` and change
```conf
data_directory = '/mnt/disks/db/postgresql/14/main'
```

## Restarting PostgreSQL

```bash
sudo systemctl start postgresql
sudo systemctl status postgresql
```

## Check new directory

```bash
sudo -u postgres psql
```

```sql
SHOW data_directory;
```
Output:
```sql
            data_directory
-----------------------------------------
/mnt/disks/db/postgresql/14/main
(1 row)
```

## Remove backup folder

```bash
sudo rm -Rf /var/lib/postgresql/14/main.bak
```

## Final restart to be sure

```bash
sudo systemctl restart postgresql
sudo systemctl status postgresql
```

## Add TimescaleDB

Note versions compability https://docs.timescale.com/timescaledb/latest/how-to-guides/upgrades/upgrade-pg/  

Note Zabbix support at current time only 2.8.x version of TimescaleDB (may change in future) https://www.zabbix.com/documentation/6.2/en/manual/introduction/whatsnew624

manual https://docs.timescale.com/install/latest/self-hosted/installation-debian/

### **Compile way**

Documentation https://docs.timescale.com/install/latest/self-hosted/installation-source/  

Tune https://docs.timescale.com/timescaledb/latest/how-to-guides/configuration/timescaledb-tune/  

Install additional packages

```bash
sudo apt install build-essential cmake postgresql-server-dev-14 libkrb5-dev
```

### **Package way**
### Add the PostgreSQL third party repository to get the latest PostgreSQL packages:

```bash
sudo apt install gnupg postgresql-common apt-transport-https lsb-release wget
```

### Run the PostgreSQL repository setup script:

```sh
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
```

### Add the TimescaleDB third party repository:

```sh
echo "deb https://packagecloud.io/timescale/timescaledb/debian/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list
```

### Install Timescale GPG key

```bash
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/timescaledb.gpg
```

### Update your local repository list:

```
sudo apt update
```

### Install TimescaleDB:
```
sudo apt install timescaledb-2-postgresql-14
```

### Tune:

```
sudo timescaledb-tune --quiet --yes
sudo systemctl restart postgresql
```