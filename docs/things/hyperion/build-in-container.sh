#!/usr/bin/env bash
# Runs inside ubuntu:24.04 (see build). Mirrors the steps of
# hyperion.ng-webos-loader's .github/workflows/build.yml:
#   1. webOS toolchain (buildroot-nc4), cached in /cache
#   2. Qt (host tools + cross build for the TV), cached in /cache
#   3. Hyperion.NG, cross-compiled, plus the libraries it needs on the TV
#   4. loader frontend + service, packaged into an ipk in /out
set -euo pipefail

: "${HYPERION_NG_REF:?}" "${QT_VERSION:?}" "${TOOLCHAIN_URL:?}" "${NODE_VERSION:?}"
TOOLCHAIN_DIR=/opt/arm-webos-linux-gnueabi_sdk-buildroot
TOOLCHAIN_FILE=$TOOLCHAIN_DIR/share/buildroot/toolchainfile.cmake
SYSROOT=$TOOLCHAIN_DIR/arm-webos-linux-gnueabi/sysroot
QT_TOOLCHAIN_DIR=$TOOLCHAIN_DIR/qt6-host
JOBS=${JOBS:-$(nproc)}

export DEBIAN_FRONTEND=noninteractive
apt-get -qq update
apt-get -qq install -y ccache git cmake build-essential flatbuffers-compiler ninja-build \
  wget xz-utils file libdbus-1-dev python3 >/dev/null

# Node.js for the frontend build and ares-package (the CI uses 14.x)
if [[ ! -x /cache/node/bin/node ]]; then
  echo ":: Node.js $NODE_VERSION"
  mkdir -p /cache/node
  wget -q -O- "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" |
    tar xJ -C /cache/node --strip-components=1
fi
export PATH=/cache/node/bin:$PATH

# The toolchain must live at its final path, relocate-sdk.sh rewrites it.
# /cache/toolchain is a volume mounted at $TOOLCHAIN_DIR.
if [[ ! -x $TOOLCHAIN_DIR/relocate-sdk.sh ]]; then
  echo ":: Toolchain"
  wget -q -O- "$TOOLCHAIN_URL" | tar xz -C "$(dirname "$TOOLCHAIN_DIR")"
  (cd "$TOOLCHAIN_DIR" && ./relocate-sdk.sh)
  rm -f /cache/qt.done
fi

if [[ ! -e /cache/qt.done || $(cat /cache/qt.done) != "$QT_VERSION" ]]; then
  echo ":: Qt $QT_VERSION"
  rm -rf /cache/qt_build && mkdir -p /cache/qt_build
  cd /cache/qt_build
  git clone -q --branch "v$QT_VERSION" --depth 1 https://github.com/qt/qtbase.git qt_source

  # host tools
  mkdir host && cd host
  cmake ../qt_source -DCMAKE_INSTALL_PREFIX="$QT_TOOLCHAIN_DIR" -DCMAKE_BUILD_TYPE=Release \
    -DQT_FEATURE_gui=OFF -DQT_FEATURE_opengl=OFF -DQT_FEATURE_dbus=ON -DQT_BUILD_TESTS=OFF \
    -DFEATURE_icu=OFF -DQT_BUILD_EXAMPLES=OFF -GNinja >/dev/null
  ninja -j"$JOBS" install >/dev/null

  # same patches as the CI
  cd ../qt_source
  mkdir -p mkspecs/devices/linux-webos-g++
  cp -r "$TOOLCHAIN_DIR/mkspecs/devices/linux-buildroot-g++" mkspecs/devices/linux-webos-g++
  sed -i '1i#define EM_AARCH64 183' src/corelib/plugin/qelfparser_p.cpp
  sed -i 's/readOnly = (statfs_buf.f_flags \& ST_RDONLY) != 0;/readOnly = false;/' src/corelib/io/qstorageinfo_linux.cpp

  # cross build
  mkdir ../base_cross && cd ../base_cross
  cmake ../qt_source -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DQT_HOST_PATH="$QT_TOOLCHAIN_DIR" \
    -DCMAKE_INSTALL_PREFIX=/usr/local/qt6 -DCMAKE_STAGING_PREFIX="$SYSROOT/usr/local/qt6" \
    -DCMAKE_BUILD_TYPE=Release -DQT_FEATURE_dbus=ON -DQT_FEATURE_gui=ON -DQT_FEATURE_widgets=ON \
    -DQT_FEATURE_opengl=OFF -DFEATURE_icu=OFF -GNinja \
    -DQt6CoreTools_DIR="$QT_TOOLCHAIN_DIR/lib/cmake/Qt6CoreTools" \
    -DQt6DBusTools_DIR="$QT_TOOLCHAIN_DIR/lib/cmake/Qt6DBusTools" \
    -DQt6WidgetsTools_DIR="$QT_TOOLCHAIN_DIR/lib/cmake/Qt6WidgetsTools" \
    -DQt6GuiTools_DIR="$QT_TOOLCHAIN_DIR/lib/cmake/Qt6GuiTools" >/dev/null
  ninja -j"$JOBS" install >/dev/null

  for mod in qtserialport qtwebsockets qtimageformats; do
    git clone -q --branch "v$QT_VERSION" --depth 1 "https://github.com/qt/$mod.git" "/cache/qt_build/$mod"
    mkdir -p "/cache/qt_build/$mod/build" && cd "/cache/qt_build/$mod/build"
    cmake .. -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DQT_HOST_PATH="$QT_TOOLCHAIN_DIR" \
      -DCMAKE_PREFIX_PATH="$SYSROOT/usr/local/qt6" -DCMAKE_INSTALL_PREFIX=/usr/local/qt6 \
      -DCMAKE_STAGING_PREFIX="$SYSROOT/usr/local/qt6" -DINPUT_openssl=runtime -DQT_FEATURE_ssl=ON \
      -GNinja >/dev/null
    ninja -j"$JOBS" install >/dev/null
  done
  echo "$QT_VERSION" > /cache/qt.done
fi

echo ":: Hyperion.NG $HYPERION_NG_REF"
rm -rf /cache/hyperion.ng
git clone -q --branch "$HYPERION_NG_REF" --depth 1 --recurse-submodules --shallow-submodules \
  https://github.com/hyperion-project/hyperion.ng /cache/hyperion.ng
mkdir /cache/hyperion.ng/build && cd /cache/hyperion.ng/build
export CCACHE_DIR=/cache/ccache
cmake .. -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" -DQT_HOST_PATH="$QT_TOOLCHAIN_DIR" \
  -DCMAKE_PREFIX_PATH="$SYSROOT/usr/local/qt6" -DPython3_EXECUTABLE="$TOOLCHAIN_DIR/bin/python3" \
  -DCMAKE_BUILD_TYPE=Release -DPLATFORM=rpi -DENABLE_CEC=OFF -DENABLE_DEV_FTDI=ON \
  -DHYPERION_LIGHT=ON -DENABLE_REMOTE_CTL=ON -DENABLE_AUDIO=OFF -DENABLE_EFFECTENGINE=ON \
  -DENABLE_JSONCHECKS=ON -DENABLE_DEV_SERIAL=ON -DENABLE_DEV_USB_HID=ON -DENABLE_DEV_TINKERFORGE=ON \
  -DENABLE_MDNS=ON -DENABLE_DEPLOY_DEPENDENCIES=OFF -DENABLE_BOBLIGHT_SERVER=ON \
  -DENABLE_FLATBUF_SERVER=ON -DENABLE_PROTOBUF_SERVER=OFF -DENABLE_FORWARDER=ON \
  -DENABLE_FLATBUF_CONNECT=ON -G Ninja >/dev/null
ninja -j"$JOBS" >/dev/null

echo ":: Collect binaries and libraries"
R=/cache/release
rm -rf $R && mkdir -p $R/python/lib/python3.10 $R/sqldrivers $R/imageformats $R/tls
cp -r -T bin $R
for i in libpython3.10.so.1.0 libpng16.so.16 libjpeg.so.8 libcrypt.so.1 libcrypto.so.1.1 libbz2.so.1 \
  libz.so.1 libssl.so.1.1 libpcre2-16.so.0 libusb-1.0.so.0 libftdi1.so.2 libudev.so.1 libxkbcommon.so.0 \
  libfontconfig.so.1 libglib-2.0.so.0 libfreetype.so.6 libgthread-2.0.so.0 libgcc_s.so.1; do
  f=$(find "$SYSROOT/usr/lib/" "$SYSROOT/lib/" -name "$i" | head -1)
  if [[ -n $f ]]; then cp -L "$f" $R/; else echo "warning: $i not found"; fi
done
for i in libstdc++.so.6 libatomic.so.1; do
  cp -L "$(find "$TOOLCHAIN_DIR/arm-webos-linux-gnueabi/lib/" -name "$i" | head -1)" $R/
done
for i in libQt6Gui.so.6 libQt6Network.so.6 libQt6Widgets.so.6 libQt6Core.so.6 libQt6Sql.so.6 \
  libQt6SerialPort.so.6 libQt6WebSockets.so.6 libQt6DBus.so.6; do
  cp -L "$SYSROOT/usr/local/qt6/lib/$i" $R/
done
for d in sqldrivers imageformats tls; do
  cp -L "$SYSROOT/usr/local/qt6/plugins/$d/"*.so $R/$d/ 2>/dev/null || true
done
cp -r "$SYSROOT/usr/lib/python3.10/"* $R/python/lib/python3.10/
STRIP=$TOOLCHAIN_DIR/bin/arm-webos-linux-gnueabi-strip
$STRIP $R/hyperiond
find $R -maxdepth 1 -name "*.so*" -exec $STRIP --strip-unneeded {} +
find $R/python/lib/python3.10/lib-dynload $R/sqldrivers $R/imageformats $R/tls -name "*.so" \
  -exec $STRIP --strip-unneeded {} +

echo ":: Loader (frontend, service, ipk)"
# Same directory name as in the CI: enyo names the frontend bundle after it
L=/cache/hyperion.ng-webos-loader
rm -rf /cache/loader $L && cp -r /src $L && cd $L
npm install --no-audit --no-fund --loglevel=error
npm run build -- --env production >/dev/null
mkdir -p service/build && cd service/build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" >/dev/null
make -s
cd ../..
mkdir -p dist && rm -rf dist/service && cp -r -T service/build/dist dist/service
rm -rf dist/service/hyperion && cp -r -T $R dist/service/hyperion
rm -f dist/service/hyperion/flatc
chmod +x dist/service/autostart.sh dist/service/loader_service dist/service/start_hyperiond \
  dist/service/hyperion/hyperiond dist/service/hyperion/hyperion-remote
chmod -R +r dist/service/hyperion
npm run package
npm run gen-manifest
cp ./*.ipk ./*.manifest.json /out/
ls -l /out
