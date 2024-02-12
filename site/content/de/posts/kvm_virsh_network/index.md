---
title: KVM/virsh Network Optimization
date: 2020-04-08
description: virtio Network speedup for virsh/KVM
---

<div style="background-color: #30df56 !important;
            color: black;
            font-weight: bold;
            padding: 20px;
            margin: 10px;
            text-align: center;
            font-family: monospace;">
  Easy Difficulty
</div>

# KVM/virsh Network Optimization

Using `libvirt/virsh` or `qemu` directly you might have noticed, that your networks are kind of slow. 10mbit slow to be exact. That's because the default NIC is kind of slow and bad and unless you are running a really esoteric Unix, have a stone-age CPU or run your VMs as non-root, you can and should use the virtio kernel drivers for network.

## Process
To successfully use `virtio`, you need to:

- load the relevant kernel modules
- change the type of the network **and** the guests to `virtio`

### Load the kernel modules
We need the following kernel modules (on the host machine), which should already be avialiable on most systems after installing qemu with the package manager:

    modprobe virtio_ring
    modprobe virtio_pci
    modprobe virtio_net
    modprobe virtio

You can check if it worked by running:

    lsmod | grep virtio

To load these modules at boot, add them to `/etc/modules`, one per line, without any other arguments:

    virtio
    virtio_net
    virtio_pci
    virtio_ring

### Edit the Guests
To show the current definition of your VM, use:

    virsh dump-xml vm_name
    
This should contain something like this:

    ...
    <interface type='network'>
      <mac address='XX:XX:XX:XX:XX:XX'/>
      <source network='default' portid='...' bridge='virbr0'/>
      <target dev='vnetX'/>
      <alias name='net0'/>
      <address type='pci' domain='0x0000'
          bus='0x01' slot='0x00' function='0x0'/>
    </interface>
    ...

Depending on your initial setup, this might already contain the line:

      <model type='virtio'/>

..if not, add the correct model type to the interface block in the VM definition with `virsh edit vm_name`
    
### Edit the network
This only applies if you are running a *virsh*-setup, rather than using only qemu directly. First, check the current contents with `virsh net-dumpxml default` (if you are using the default network). This should look something like this:
    
    <network connections='18'>
      <name>default</name>
      <uuid>...</uuid>
      <forward mode='nat'>
        <nat>
          <port start='1024' end='65535'/>
        </nat>
      </forward>
      <bridge name='virbr0' stp='on' delay='0'/>
      <mac address='XX:XX:XX:XX:XX:XX'/>
      <ip address='192.168.122.1' netmask='255.255.255.0'>
        <dhcp>
            ...
        </dhcp>
      </ip>
    </network>

Add the virtio model-type to the toplevel network block aswell:

    virsh net-edit default

Now reboot the host or recreate the network and reboot the guests.

## Test the speed
The changes should now have been applied, check the speed by executing a *dd-pipe-ssh* or similar command on the host machine:

    dd if=/dev/zero status=progress bs=4096 count=1048576 | ssh VM_ADDRESS 'cat > /dev/null'

Unfortunally the interfaces will still be listed with 10mbit speed in ethtool or `/proc/interfaces/...` - there is currently not fix for this. If this breaks your monitoring setups checking for bandwith usage, you have to handle it externally.

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Linux, KVM/qemu, virsh, Network, Kernel_ </sup>
