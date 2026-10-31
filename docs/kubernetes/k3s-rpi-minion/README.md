# k3s agent on a Raspberry Pi

How `rpi-media` (Raspberry Pi 4, Raspberry Pi OS / Debian 13 trixie) joins the
cluster as a k3s agent. The server is `filer`.

On the Pi:

```sh
sudo apt update && sudo apt full-upgrade
sudo hostnamectl set-hostname rpi-media
sudo sed -i 's/raspberrypi/rpi-media/' /etc/hosts

# The firmware disables the memory cgroup by default, k3s needs it
sudo sed -i '1 s/$/ cgroup_enable=memory/' /boot/firmware/cmdline.txt
sudo reboot
```

After the reboot, `/sys/fs/cgroup/cgroup.controllers` should list `memory`.

Install k3s with the same version as the server (`kubectl get nodes`), without
starting it:

```sh
curl -sfL https://get.k3s.io | sudo INSTALL_K3S_VERSION=v1.35.2+k3s1 \
  INSTALL_K3S_SKIP_START=true INSTALL_K3S_SKIP_ENABLE=true \
  K3S_URL=https://filer:6443 K3S_TOKEN_FILE=/etc/rancher/k3s/token sh
```

`sudo k3s check-config` complains about missing `CONFIG_IP_NF_*` options; that
is fine, k3s uses nftables there.

If the node was in the cluster before (reinstalled Pi), delete the old Node
object first. Otherwise k3s rejects the agent because its node password
changed, and pods on the old node stay in Terminating:

```sh
kubectl delete node rpi-media
```

Copy the join token from the server and start the agent:

```sh
ssh filer sudo cat /var/lib/rancher/k3s/server/token |
  ssh pi@rpi-media 'sudo install -D -m 600 /dev/stdin /etc/rancher/k3s/token && sudo systemctl enable --now k3s-agent'
```

The node should be `Ready` within a minute, with node-exporter and the svclb
pods running on it.

To upgrade k3s, rerun the install command with the new version.
