# NUT configuration

https://networkupstools.org/docs/user-manual.chunked/index.html
https://wiki.ipfire.org/addons/nut/detailed

## Install

**Server**
*includes `nut-server` and `nut-client`
```
apt install nut
```

**Client**

```
apt install nut-client
```

**Example upssched.conf**

```conf
CMDSCRIPT /etc/nut/upssched-cmd

PIPEFN /etc/nut/upssched.pipe
LOCKFN /etc/nut/upssched.lock

# -------------------------------------------------------------
AT FSD * EXECUTE got_fsd
AT SHUTDOWN * EXECUTE got_shutdown

```


**Example upssched-cmd**

```bash
#!/bin/sh
# `%0A` character-set to make new line in messages
case $1 in
    got_fsd)
BATT=`upsc exa@192.168.1.102 battery.charge | grep -v SSL`
UPSLOG=`cat /var/log/syslog | grep ups | tail -50`
/usr/local/bin/telegramsend "Server got FSD %0ABattary charge = $BATT%0ALog messages = $UPSLOG"
    ;;
    got_shutdown)
BATT=`upsc exa@192.168.1.102 battery.charge|grep -v SSL`
UPSLOG=`cat /var/log/syslog | grep ups | tail -50`
/usr/local/bin/telegramsend "Server SHUTTING DOWN%0ABattary charge = $BATT%0ALOGS = $UPSLOG"
    ;;
    *)
echo "wrong parameter";;
esac

```
**Telegram message send**

Create file 

```
nano /usr/local/bin/telegramsend
```
contents:
```bash
#!/bin/bash

GROUP_ID=<ID>
BOT_TOKEN=<TOKEN>

# this 3 checks (if) are not necessary but should be convenient
if [ "$1" == "-h" ]; then
  echo "Usage: `basename $0` \"text message\""
  exit 0
fi

if [ -z "$1" ]
  then
    echo "Add message text as second arguments"
    exit 0
fi

if [ "$#" -ne 1 ]; then
    echo "You can pass only one argument. For string with spaces put it on
quotes"
    exit 0
fi

curl -s --data "text=$1" --data "chat_id=$GROUP_ID" 'https://api.telegram.org/bot'$BOT_TOKEN'/sendMessage' > /dev/null
```

Fix permissions

```bash
chmod +x /usr/local/bin/telegramsend
```