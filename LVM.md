# Create LVM from physical disk

https://linuxhint.com/lvm-how-to-create-logical-volumes-and-filesystems/

Check
```bash
lvm version
```

if not present then install

```bash
sudo apt install lvm2 -y
```

**Creating Physical Volume**

```bash
sudo pvscan
```

If no pv found, scan 

```bash
sudo lvmdiskscan
```

Assuming we want to add **/dev/sdc** disk. Disk should be *unmounted*, if not, run

```bash
sudo umount /dev/sdc
```

Initialize the block device as a physical volume

```bash
sudo pvcreate /dev/sdc
```

**Creating Volume Group**

List existing vg

```
sudo vgdisplay
```

Create vg

```
sudo vgcreate vg01 /dev/sdc
```

Activate vg

```
sudo vgchange -a y vg01
```

**Creating Logical Volume**

Scan for lv

```bash
sudo lvscan
```

**LVM-Thin**

```bash
lvcreate -l100%FREE --type thin-pool --poolmetadatasize=8G --name thin-data vg01
```

storage-comparison  
https://pve.proxmox.com/wiki/Storage