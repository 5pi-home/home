# Hyperion: ambient light from the TV

The TV's picture is mirrored onto WLED LED strips:

```
LG TV (webOS)                                           WLED controllers
  PicCap ── grabs the picture ──> Hyperion.NG ── DDP ──> Sofa, Bed, ...
                                  (on the TV, port 8090)
```

- **TV**: LG OLED65B7D-Z (webOS 3.5), `lgwebostv.fritz.box`, rooted with
  [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel), SSH
  as root enabled.
- **[PicCap](https://github.com/TBSniller/piccap)** (frontend for
  [hyperion-webos](https://github.com/webosbrew/hyperion-webos)): captures the
  video and sends it to Hyperion.NG.
- **[Hyperion.NG](https://github.com/hyperion-project/hyperion.ng)** runs on
  the TV, packaged by
  [hyperion.ng-webos-loader](https://github.com/webosbrew/hyperion.ng-webos-loader).
  Web UI: http://lgwebostv:8090. Config in `/home/root/.hyperion`, log in
  `/tmp/hyperion.ng.log`.
- **WLED** controllers. Hyperion sends to them via DDP (seen on Sofa and Bed;
  which ones Hyperion drives is in its LED device config). Each controller
  lists the others it found (`/json/nodes`):

  | Name    | IP              | Chip     | LEDs                       |
  |---------|-----------------|----------|----------------------------|
  | Desk    | 192.168.178.69  | ESP8266  | 140 SK6812 RGBW            |
  | Kitchen | 192.168.178.80  | ESP8266  | 40 SK6812 RGBW             |
  | TV      | 192.168.178.81  | ESP32    | 60 SK6812 RGBW             |
  | Sofa    | 192.168.178.122 | ESP32-C3 | 60 SK6812 RGBW             |
  | Bed     | 192.168.178.132 | ESP32-C3 | 60 SK6812 RGBW             |
  | Spot    | 192.168.178.133 | ESP32    | 30 WS281x RGB, 850 mA max  |
  | Terrace | 192.168.178.162 | ESP32-C3 | 60 SK6812 RGBW             |

  Desk sends WLED UDP sync, the others receive it.

## Building Hyperion.NG for the TV

Upstream's CI publishes an ipk (in the loader's
[releases](https://github.com/webosbrew/hyperion.ng-webos-loader/releases)
and in Homebrew Channel). To build it yourself, e.g. to patch it, on a Linux
machine with podman:

```sh
./build
```

It runs the steps of the loader's CI (`.github/workflows/build.yml`) in an
`ubuntu:24.04` container: webOS toolchain
([buildroot-nc4](https://github.com/openlgtv/buildroot-nc4)), Qt
cross-compiled for the TV, Hyperion.NG, then the loader's frontend and service
into `out/org.webosbrew.hyperion.ng.loader_<version>_all.ipk`. The first build
takes about an hour (Qt); toolchain, Qt and ccache are kept in `cache/`, later
builds take a few minutes.

Versions are set at the top of `build` and follow the loader's CI. To build
something else:

```sh
HYPERION_NG_REF=master ./build             # Hyperion.NG nightly
./build ~/src/hyperion.ng-webos-loader     # a local loader checkout
```

## Updating the TV

Back up the configuration first (export it in the Hyperion web UI's general
settings).

Copy the ipk to the TV and install it there:

```sh
scp out/org.webosbrew.hyperion.ng.loader_2.2.1_all.ipk root@lgwebostv:/tmp/hyperion.ipk
ssh root@lgwebostv
```

On the TV:

```sh
luna-send -n 1 'luna://org.webosbrew.hyperion.ng.loader.service/stop' '{}'
luna-send-pub -i 'luna://com.webos.appInstallService/dev/install' \
  '{"id":"com.ares.defaultName","ipkUrl":"/tmp/hyperion.ipk","subscribe":true}'
# wait for "installed", then Ctrl-C
/media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service/elevate-service \
  org.webosbrew.hyperion.ng.loader.service
luna-send -n 1 'luna://org.webosbrew.hyperion.ng.loader.service/start' '{}'
rm /tmp/hyperion.ipk
```

`elevate-service` lets the service run as root, which Hyperion needs. Homebrew
Channel does this itself for apps installed through it, not for ipks installed
by hand.

Check with `luna-send -n 1 'luna://org.webosbrew.hyperion.ng.loader.service/status' '{}'`
and the web UI. The configuration in `/home/root/.hyperion` is kept.
Autostart (Hyperion.NG app → Autostart) links
`/var/lib/webosbrew/init.d/90-start_hyperiond` to the service's
`autostart.sh` and survives updates.
