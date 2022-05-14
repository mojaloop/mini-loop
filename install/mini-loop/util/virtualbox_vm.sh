#!/usr/bin/env bash
# create a vbox VM so I can test various falvours of linux 
VBoxManage createvm --name fedora1 --ostype Fedora_64  --register --basefolder /root/VMs
VBoxManage modifyvm fedora1 --cpus 2 --memory 8192 --vram 12
#VBoxManage modifyvm fedora1 --nic1 bridged --bridgeadapter1 eth0
VBoxManage modifyvm fedora1 --nic1 nat 
#VBoxManage createhd --filename /root/vms/fedora1.vdi --size 50000 --variant Standard
VBoxManage storagectl fedora1 --name "SATA Controller" --add sata --bootable on
VBoxManage storageattach fedora1 --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium /root/vms/fedora1.vdi
VBoxManage storagectl fedora1 --name "IDE Controller" --add ide
VBoxManage storageattach fedora1 --storagectl "IDE Controller" --port 0  --device 0 --type dvddrive --medium //root/fedora.iso
VBoxHeadless --startvm fedora1


#VBoxManage unregistervm --delete fedora1