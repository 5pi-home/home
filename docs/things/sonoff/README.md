# Flash it
## Wire it
```
  ____
 | USB|
 |    |
 |    |
 |+-----4 GND
 ||  +--2
 |::::|
  ||||
  |  +- 1 VCC
  +-----3
```

## Flash it
- Connect USB
- Connect all but VCC
- Hold button while connecting VCC
- Wait 2
- `esptool --port /dev/ttyUSB0  write_flash -fs 1MB -fm dout 0x0 sonoff.bin`

## Configure it
- Press Button 4x until short flash
- Connect to Wifi
- Configure Wifi
- Access Web UI
- Configure -> Configure Module -> Sonoff S2X
- Configure -> Configure MQTT -> Host = 192.168.1.1 #FIXME: mdns discovery
  should work
- Console -> `SetOption19 1`

# OpenWrt
- Install avahi
- `echo 192.168.1.1 mqtt.local > /etc/avahi/host`
