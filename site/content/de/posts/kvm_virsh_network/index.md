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

Using `libvirt/virsh` or `QEMU` directly you might have noticed that your networks might be kind of slow. That's because using the default NIC itself quite suboptimal and unless you are running some really esoteric Unix or have a stone-age CPU you can and should use the virtio kernel drivers for networking.

## Process
To successfully use `virtio`, you need to:

- load the relevant kernel modules (if they aren't loaded by default)
- change the guests's network-type to `virtio`

### Kernel modules
#### On the hypervisor
We need the following kernel module on the host machine, which should already be available on most systems after installing QEMU with the package manager:

    modprobe vhost_net

#### On the guest
Additionally, you need these kernel modules on all guests, which are usually automatically loaded, but just in case:

    modprobe virtio_ring
    modprobe virtio_net
    modprobe virtio_pci
    modprobe virtio

You can check if it worked by running:

    lsmod | grep virtio

#### Persistence
In fact it's not actually required to load all modules individually since virtio and virtio_ring are dependencies of `virtio_net`.
To load modules during boot, add them to `/etc/modules`, one per line, without any other arguments.

    # on host
    vhost_net

    # on guest
    virtio_net
    virtio_pci

### Edit the Guests
To show the current definition of your VM, use:

    virsh dumpxml vm_name
    
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

If not, add the correct model type to the interface block in the VM definition with `virsh edit vm_name`

## Test the speed
Shut down and start (not `/sbin/reboot` in the guests!) all edited guests now to apply the changes. Check the speed by executing a *dd-pipe-ssh* or similar command on the host machine:

    # simplest way to test, but may be inaccurate for very high speeds because of ssh-overhead
    dd if=/dev/zero status=progress bs=4096 count=1048576 | ssh -oCompression=no VM_ADDRESS 'cat > /dev/null'

    # more accurate test:
    # on the guest
    nc -l -p 5001 > /dev/null
    # on the host
    dd if=/dev/zero bs=4M count=5000 status=progress | nc -N <VM_ADDRESS> 5001

One final note: The default reported speed for interfaces is often 10 Mbit/s or not set at all. This is relevant if you are using monitoring software, which might be calculating the saturation of a network interface based on this value. You can usually change this setting with:

    sudo ethtool -s eth0 speed 1000 duplex full # 1 Gbit/s

But this change does not persist across reboots, consider adding it as a systemd-service. If this command doesn't work you'll have to refer to relevant documentation.

<sup style="font-style: italic;">by Yannik Schmidt</sup><br>
<sup>**Tags:** _Linux, KVM/QEMU, virsh, Network, Kernel_ </sup>
