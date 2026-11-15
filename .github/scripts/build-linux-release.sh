#!/usr/bin/env bash
# Builds the Linux release of Spice Shaker to build/spice-shaker. Runs inside the build container of the release workflow
# (see release.yml), from the root of the repository, with the Spice compiler on the PATH and SPICE_STD_DIR set.
#
# glibc is linked dynamically: a static glibc still loads the NSS modules of /etc/nsswitch.conf (e.g. mdns4_minimal) with
# dlopen for getaddrinfo, and they bring the libc.so.6 of the host into the process, which crashes next to the static glibc
# of another version (#17). The executable needs the glibc of the container or a newer one. OpenSSL is linked statically,
# so that the executable runs without a particular OpenSSL version installed.
#
# Optional: OWNER (uid:gid) gets the build directory, so that the runner can modify the output of the root container.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq --no-install-recommends clang lld libssl-dev pkg-config >/dev/null

# std/bindings/openssl takes its linker flags from 'pkg-config --cflags --libs openssl'. This openssl.pc puts the OpenSSL
# archives (and the private dependencies they need) between -Bstatic and -Bdynamic, and leaves the libraries that are part
# of glibc dynamic.
pc_dir="$(mktemp -d)"
static_libs=()
glibc_libs=()
for flag in $(pkg-config --static --libs openssl); do
  case "$flag" in
    -lc|-ldl|-lm|-lpthread|-lrt|-pthread) glibc_libs+=("$flag") ;;
    *) static_libs+=("$flag") ;;
  esac
done
cat > "$pc_dir/openssl.pc" <<PC
Name: OpenSSL
Description: OpenSSL, linked statically into a dynamically linked executable
Version: $(pkg-config --modversion openssl)
Cflags: $(pkg-config --cflags openssl)
Libs: -Wl,-Bstatic ${static_libs[*]} -Wl,-Bdynamic ${glibc_libs[*]}
PC
export PKG_CONFIG_PATH="$pc_dir"
echo "OpenSSL linker flags: $(pkg-config --cflags --libs openssl)"

mkdir -p build
cd build
spice build -O3 -lto --output spice-shaker ../src/main.spice
chmod +x spice-shaker
./spice-shaker --version
if [ -n "${OWNER:-}" ]; then
  chown -R "$OWNER" .
fi
