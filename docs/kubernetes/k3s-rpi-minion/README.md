# Install k3s client on hypriotos
First follow https://blog.hypriot.com/getting-started-with-docker-on-your-arm-device/
Then:

```
systemctl disable docker
hostnamectl set-hostname rpi-living
sed -i 's/black-pearl/rpi-living/g' /etc/hosts


TOKEN= # Get token from /data/k3s/server/node-token
curl -Lsf https://github.com/rancher/k3s/releases/download/v0.3.0/k3s-armhf | \
  install -m755 /dev/stdin /usr/local/bin/k3s

curl -Lsf https://raw.githubusercontent.com/rancher/k3s/6de915d351a873de74d5f049b295e73925726980/k3s.service | \
  sed "s|k3s server|k3s agent --server https://192.168.1.1:6443 --token ${TOKEN}|" | \
  install -m600 /dev/stdin /etc/systemd/system/k3s.service
```
