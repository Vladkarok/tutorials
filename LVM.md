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

# Resize lvm
https://pve.proxmox.com/wiki/Resize_disks <br>
Install `parted`
```
apt install parted
```
**Without EFI**  
Define partition to resize
```
lsblk
```
output:
```
sda                                 8:0    0   74G  0 disk
├─sda1                              8:1    0  487M  0 part /boot
├─sda2                              8:2    0    1K  0 part
└─sda5                              8:5    0 63.5G  0 part
  ├─deb--nextcloud--ml--vg-root   254:0    0 62.6G  0 lvm  /
  └─deb--nextcloud--ml--vg-swap_1 254:1    0  976M  0 lvm  [SWAP]
```
Target partitions is `sda5`  

```
parted /dev/sda
(parted) print
``` 
output:
```
Model: QEMU QEMU HARDDISK (scsi)
Disk /dev/sda: 79.5GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type      File system  Flags
 1      1049kB  512MB   511MB   primary   ext2         boot
 2      513MB   68.7GB  68.2GB  extended
 5      513MB   68.7GB  68.2GB  logical                lvm
 ```
You will want to resize the 2nd partition first (extended):

```
(parted) resizepart 2 100%
(parted) resizepart 5 100%
```
Check new size:
```
(parted) print
```
output:
```
Model: QEMU QEMU HARDDISK (scsi)
Disk /dev/sda: 79.5GB
Sector size (logical/physical): 512B/512B
Partition Table: msdos
Disk Flags:

Number  Start   End     Size    Type      File system  Flags
 1      1049kB  512MB   511MB   primary   ext2         boot
 2      513MB   79.5GB  78.9GB  extended
 5      513MB   79.5GB  78.9GB  logical                lvm
 ```
 Now you can exit from **parted**
 ```
 (parted) quit
 ```
**With EFI**
Print the current partition table
```
fdisk -l /dev/vda | grep ^/dev
```
output:
```
/dev/sda1     2048   1050623   1048576  512M EFI System
/dev/sda2  1050624   2050047    999424  488M Linux filesystem
/dev/sda3  2050048 134215679 132165632   63G Linux LVM
```
Resize the partition 3 (LVM PV) to occupy the whole remaining space of the hard drive)
```
parted /dev/sda
(parted) print
```

output:
```
Warning: Not all of the space available to /dev/sda appears to be used, you can fix the GPT to use all of the space (an extra 20971520 blocks) or continue
with the current setting?
Fix/Ignore? F
```

```
(parted) resizepart 3 100%
(parted) quit
```



**Resize physical volume.**
```
pvresize /dev/sda5
```
output:
```
Physical volume "/dev/sda5" changed
1 physical volume(s) resized or updated / 0 physical volume(s) not resized
```
Check:
```
pvs
```
output:
```
 /dev/sda5  deb-nextcloud-ml-vg lvm2 a--  <73.52g 10.00g
```
List logical volumes:
```
lvdisplay
```
output:
```
  --- Logical volume ---
  LV Path                /dev/deb-nextcloud-ml-vg/root
  LV Name                root
  VG Name                deb-nextcloud-ml-vg
  LV UUID                7WEJht-e8hx-JlxD-bHN7-3SjB-0DRm-yojLuz
  LV Write Access        read/write
  LV Creation host, time deb-nextcloud-ml, 2023-06-02 19:24:28 +0300
  LV Status              available
  # open                 1
  LV Size                62.56 GiB
  Current LE             16016
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     256
  Block device           254:0
...
```
Here we use all remaining space from volume group
```
lvresize --extents +100%FREE --resizefs /dev/deb-nextcloud-ml-vg/root
```
output:
```
  Size of logical volume deb-nextcloud-ml-vg/root changed from 62.56 GiB (16016 extents) to <72.57 GiB (18577 extents).
  Logical volume deb-nextcloud-ml-vg/root successfully resized.
resize2fs 1.46.2 (28-Feb-2021)
Filesystem at /dev/mapper/deb--nextcloud--ml--vg-root is mounted on /; on-line resizing required
old_desc_blocks = 8, new_desc_blocks = 10
The filesystem on /dev/mapper/deb--nextcloud--ml--vg-root is now 19022848 (4k) blocks long.

```
To add 20GB you can use the following command:
```
lvresize --size +20G --resizefs /dev/deb-nextcloud-ml-vg/root
```
