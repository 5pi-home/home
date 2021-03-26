# Kubernetes
*Edited and updated https://5pi.de/2019/05/10/k8s-on-openwrt/*

Master based on [apu2d4](https://pcengines.ch/apu2d4.htm) with 16GB mSATA SSD.

Setting this up with OpenWrt was a matter of minutes:

1. Write openwrt `x86_64` image with `dd` to a USB drive
2. Boot the apu2 from it
3. Use `dd` to write USB drive to SSD

## Custom Kernel
The default OpenWrt Kernel for `x86_64` doesn't include the necessary features
to run Kubernetes, so I had to build my own image. I've disabled some features I
won't use and enabled options for cgroups, namespaces, overlayfs and the
required networking options. 

You can download a custom openwrt build with these features enabled from:
https://circleci.com/gh/5pi-home/openwrt/25#artifacts/containers/0

You can find my config diff
[here](https://github.com/5pi-home/openwrt/blob/master/config) (created by
`./scripts/diffconfig.sh`). If you want to create your own image, you need the
following options:

**For process and resource isolation:**
```
CONFIG_KERNEL_BLK_CGROUP=y
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_CPUACCT=y
CONFIG_KERNEL_CGROUP_DEVICE=y
CONFIG_KERNEL_CGROUP_FREEZER=y
CONFIG_KERNEL_CGROUP_PIDS=y
CONFIG_KERNEL_CGROUP_SCHED=y
CONFIG_KERNEL_CPUSETS=y
CONFIG_KERNEL_DEVPTS_MULTIPLE_INSTANCES=y
CONFIG_KERNEL_FAIR_GROUP_SCHED=y
CONFIG_KERNEL_FREEZER=y
CONFIG_KERNEL_IPC_NS=y
CONFIG_KERNEL_KEYS=y
CONFIG_KERNEL_LXC_MISC=y
CONFIG_KERNEL_MEMCG=y
CONFIG_KERNEL_NAMESPACES=y
CONFIG_KERNEL_NETPRIO_CGROUP=y
CONFIG_KERNEL_NET_CLS_CGROUP=y
CONFIG_KERNEL_NET_NS=y
CONFIG_KERNEL_PID_NS=y
CONFIG_KERNEL_POSIX_MQUEUE=y
CONFIG_KERNEL_PROC_PID_CPUSET=y
CONFIG_KERNEL_RESOURCE_COUNTERS=y
CONFIG_KERNEL_SECCOMP=y
CONFIG_KERNEL_SECCOMP_FILTER=y
CONFIG_KERNEL_USER_NS=y
CONFIG_KERNEL_UTS_NS=y
```

**For networking:**
```
CONFIG_PACKAGE_ip-bridge=y
CONFIG_PACKAGE_ip-full=y
CONFIG_PACKAGE_ipset=y
CONFIG_PACKAGE_iptables-mod-conntrack-extra=y
CONFIG_PACKAGE_iptables-mod-extra=y
CONFIG_PACKAGE_iptables-mod-ipopt=y
CONFIG_PACKAGE_kmod-asn1-decoder=y
CONFIG_PACKAGE_kmod-br-netfilter=y
CONFIG_PACKAGE_kmod-ikconfig=y
CONFIG_PACKAGE_kmod-ipt-conntrack-extra=y
CONFIG_PACKAGE_kmod-ipt-extra=y
CONFIG_PACKAGE_kmod-ipt-ipopt=y
CONFIG_PACKAGE_kmod-ipt-ipset=y
CONFIG_PACKAGE_kmod-ipt-raw=y
CONFIG_PACKAGE_kmod-iptunnel=y
CONFIG_PACKAGE_kmod-nf-conntrack-netlink=y
CONFIG_PACKAGE_kmod-nf-ipvs=y
CONFIG_PACKAGE_kmod-nfnetlink=y
CONFIG_PACKAGE_kmod-nls-base=y
CONFIG_PACKAGE_kmod-udptunnel4=y
CONFIG_PACKAGE_kmod-udptunnel6=y
CONFIG_PACKAGE_kmod-veth=y
CONFIG_PACKAGE_kmod-vxlan=y
CONFIG_PACKAGE_libnetfilter-conntrack=y
CONFIG_PACKAGE_libnfnetlink=y
```

The required `overlayfs` module for the container engines storage driver should
be already enabled.

### Build it yourself
To build your own image, start by cloning `git@github.com:openwrt/openwrt.git`
and run `./scripts/feeds update -a` to include the package feeds.

Then run `make menuconfig` to set your target hardware, exit again and run `make
defconfig`. That will set the default config for the target hardware.

Now you can either run `make menuconfig` again and select the options from above
manually or just edit `.config` to paste the options from above.

After that you should be able to build your image by running `make`.

You should save the output of `./scripts/diffconfig.sh` somewhere so be able to
recreate your image in the future.

Now it's time to upgrade OpenWrt. I just `scp` the image to the router and use
[sysupgrade](https://openwrt.org/docs/guide-user/installation/sysupgrade.cli) to
apply the new image.

If you still have trouble starting docker you can run Docker's [check-config.sh
script](https://github.com/moby/moby/blob/master/contrib/check-config.sh) to
make sure all necessary features are enabled. You'd need to install bash first
and have `CONFIG_PACKAGE_kmod-ikconfig=y` enabled.

## Kubernetes (k3s)
[k3s](https://k3s.io/) is a lightweight Kubernetes implementation which replaces
etcd3 by sqlite3 which trades high availability by easier operations.  It also
includes containerd, so no need to install Docker.

I've created [k3s-openwrt](https://github.com/discordianfish/k3s-openwrt) which
builds OpenWrt packages from k3s binaries. Again, feel free to use my
[releases](https://github.com/discordianfish/k3s-openwrt/releases) if you don't
want to build it yourself.

Depending on your setup, you might need to configure your firewall properly to
allow traffic from and to the pod network. In my case I've created a new
interface definition for the cni0 interface:

**/etc/config/network**:
```
config interface 'k8s'
	option proto 'none'
	option ifname 'cni0'
```

And a zone which allows input/output/forward traffic:
**/etc/config/firewall**:
```
config zone
	option name 'k8s'
	option input 'ACCEPT'
	option output 'ACCEPT'
	option forward 'ACCEPT'
	option network 'k8s'
```
