# Linux cloud images

source - https://pve.proxmox.com/pve-docs/pve-admin-guide.html#qm_cloud_init

## Debian images
repo - https://cloud.debian.org/images/cloud/

https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2

## Ubuntu images

repo - https://cloud-images.ubuntu.com/

https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

## Proxmox

### download the image
```bash
wget https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2
```

### resize image

```
qemu-img resize debian-11-generic-amd64.qcow2 32G
```

### create a new VM with VirtIO SCSI controller

```
qm create 9000 --memory 2048 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci
```

### import the downloaded disk to the `local-lvm` storage, attaching it as a SCSI drive

```
qm set 9000 --scsi0 local-lvm:0,import-from=debian-11-generic-amd64.qcow2
```

### change virtual consile

```
qm set 9000 --serial0 socket --vga serial0
```

### add cloud-init drive

```
qm set 9000 --ide2 local-lvm:cloudinit
```

### Adjust needed config in GUI

- boot at startup
- boot disk
- cloud-init params

## Create template from this vm
>! Do not run this machine before templating it!

## Adjust params to new machine and launch it

## install qemu-agent

```bash
sudo apt update
sudo apt install qemu-guest-agent gnupg rsync -y
```