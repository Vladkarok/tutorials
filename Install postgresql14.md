[source](https://www.postgresql.org/download/linux/debian/)

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