[source](https://cloud.google.com/compute/docs/disks/add-persistent-disk)
## 1 Add disk in proxmox
## 2 List disk in VM

```bash
lsblk
```

output

```
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda       8:0    0   32G  0 disk
├─sda1    8:1    0 31.9G  0 part /
├─sda14   8:14   0    3M  0 part
└─sda15   8:15   0  124M  0 part /boot/efi
sdb       8:16   0   32G  0 disk
sr0      11:0    1    4M  0 rom
sr1      11:1    1 1024M  0 rom
```

> Our disk is **sdb**

## 3 Create mounting directory

```bash
sudo mkdir -p /mnt/disks/db
```

### 4 Adjust permissions if needed 
For this example, grant write access to the disk for all users.

```bash
sudo chmod a+w /mnt/disks/db
```

## 5 Mount disk

```bash
sudo mount -o discard,defaults /dev/sdb /mnt/disks/db
```

## 6 Create backup of fstab just in case 

```bash
sudo cp /etc/fstab /etc/fstab.backup
```

## 7 Find out UUID of new disk

```bash
sudo blkid /dev/sdb
```

Output:

```bash
/dev/sdb: UUID="6ff6d70d-ff0c-4cf4-b57b-410090fc28a9" BLOCK_SIZE="4096" TYPE="ext4"
```

## 8 Edit **fstab**

Add next line:

```
UUID=6ff6d70d-ff0c-4cf4-b57b-410090fc28a9 /mnt/disks/db ext4 discard,defaults,nofail 0 2
```

`nofail` is one of the options described in [man](https://man7.org/linux/man-pages/man5/fstab.5.html)

## 9 Reboot to test 