### ZLIB ###
_build_zlib() {
local VERSION="1.2.11"
local FOLDER="zlib-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="https://zlib.net/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --prefix="${DEPS}" --libdir="${DEST}/lib" --shared
make
make install
popd
}

### BZIP ###
_build_bzip() {
local VERSION="1.0.8"
local FOLDER="bzip2-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="https://sourceware.org/pub/bzip2/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
sed -i -e "s/all: libbz2.a bzip2 bzip2recover test/all: libbz2.a bzip2 bzip2recover/" Makefile
make -f Makefile-libbz2_so CC="${CC}" AR="${AR}" RANLIB="${RANLIB}" CFLAGS="${CFLAGS} -fpic -fPIC -Wall -D_FILE_OFFSET_BITS=64"
ln -s libbz2.so.1.0.6 libbz2.so
cp -avR *.h "${DEPS}/include/"
cp -avR *.so* "${DEST}/lib/"
popd
}

### OPENSSL ###
_build_openssl() {
local VERSION="1.1.1g"
local FOLDER="openssl-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="https://www.openssl.org/source/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./Configure --prefix="${DEPS}" --openssldir="${DEST}/etc/ssl" \
  zlib-dynamic --with-zlib-include="${DEPS}/include" --with-zlib-lib="${DEPS}/lib" \
  shared threads linux-armv4 -DL_ENDIAN ${CFLAGS} ${LDFLAGS} \
  -Wa,--noexecstack -Wl,-z,noexecstack
sed -i -e "s/-O3//g" Makefile
make
make install_sw
cp -vfa "${DEPS}/lib/libssl.so"* "${DEST}/lib/"
cp -vfa "${DEPS}/lib/libcrypto.so"* "${DEST}/lib/"
cp -vfaR "${DEPS}/lib/engines"* "${DEST}/lib/"
cp -vfaR "${DEPS}/lib/pkgconfig" "${DEST}/lib/"
rm -vf "${DEPS}/lib/libcrypto.a" "${DEPS}/lib/libssl.a"
popd
}

### NCURSES ###
_build_ncurses() {
local VERSION="6.2"
local FOLDER="ncurses-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="https://invisible-mirror.net/archives/ncurses/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --host="${HOST}" --prefix="${DEPS}" --libdir="${DEST}/lib" --datadir="${DEST}/share" --with-shared --enable-rpath --no-grafts
make
make install
rm -v "${DEST}/lib"/*.a
popd
}

### SQLITE ###
_build_sqlite() {
local VERSION="3330000"
local FOLDER="sqlite-autoconf-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="https://www.sqlite.org/2017/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --host="${HOST}" --prefix="${DEPS}" --libdir="${DEST}/lib" --disable-static
make
make install
popd
}

### LIBFFI ###
_build_libffi() {
local VERSION="3.3"
local FOLDER="libffi-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="ftp://sourceware.org/pub/libffi/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --host="${HOST}" --prefix="${DEPS}" --libdir="${DEST}/lib" --disable-static
make
make install
mkdir -p "${DEPS}/include/"
cp -v "${DEST}/lib/${FOLDER}/include"/* "${DEPS}/include/"
popd
}

### EXPAT ###
_build_expat() {
local VERSION="2.2.9"
local FOLDER="expat-${VERSION}"
local FILE="${FOLDER}.tar.bz2"
local URL="https://github.com/libexpat/libexpat/releases/download/R_2_2_9/${FILE}"

_download_bz2 "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --host="${HOST}" --prefix="${DEPS}" --libdir="${DEST}/lib" --disable-static
make
make install
popd
}

### PYTHON3 ###
_build_python() {
local VERSION="3.8.5"
local FOLDER="Python-${VERSION}"
local FILE="${FOLDER}.tgz"
local URL="https://www.python.org/ftp/python/${VERSION}/${FILE}"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"

if [ -d "target/${FOLDER}-native" ]; then
  rm -fvR "target/${FOLDER}-native"
fi
cp -avR "target/${FOLDER}" "target/${FOLDER}-native"
( source uncrosscompile.sh
  pushd "target/${FOLDER}-native"
  ./configure
  make )

pushd "target/${FOLDER}"
export _PYTHON_HOST_PLATFORM="linux-armv7l"
./configure --host="${HOST}" --build="$(uname -p)" --prefix="${DEST}" --mandir="${DEST}/man" --enable-shared --enable-ipv6 --with-system-ffi --with-system-expat \
  PYTHON_FOR_BUILD="_PYTHON_PROJECT_BASE=${PWD} _PYTHON_HOST_PLATFORM=${_PYTHON_HOST_PLATFORM} PYTHONPATH=${PWD}/build/lib.${_PYTHON_HOST_PLATFORM}-3.5:${PWD}/Lib:${PWD}/Lib/plat-linux2 ${PWD}/../${FOLDER}-native/python" \
  CPPFLAGS="${CPPFLAGS} -I${DEPS}/include/ncurses" LDFLAGS="${LDFLAGS} -L${PWD}"\
  ac_cv_have_long_long_format=yes ac_cv_buggy_getaddrinfo=no ac_cv_file__dev_ptmx=yes ac_cv_file__dev_ptc=no
make
make install PYTHON_FOR_BUILD="_PYTHON_PROJECT_BASE=${PWD} _PYTHON_HOST_PLATFORM=${_PYTHON_HOST_PLATFORM} PYTHONPATH=${PWD}/build ${PWD}/../${FOLDER}-native/python"
rm -vfr "${DEST}/lib/python3.5/test"
popd
}

### SETUPTOOLS ###
_build_setuptools() {
# setup qemu static for this one:
# https://wiki.debian.org/QemuUserEmulation
# apt-get install binfmt-support qemu-user-static
# http://nairobi-embedded.org/qemu_usermode.html#qemu_ld_prefix
# export QEMU_LD_PREFIX="${HOME}/xtools/toolchain/${DROBO}/${HOST}/libc"

local VERSION="49.6.0"
local FOLDER="setuptools-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="https://github.com/pypa/setuptools/archive/v${VERSION}.tar.gz"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
sed -e "22i${DEST}/etc/ssl/certs/ca-certificates.crt" \
    -e "22,29d" \
    -i setuptools/ssl_support.py
QEMU_LD_PREFIX="${HOME}/xtools/toolchain/${DROBO}/${HOST}/libc" \
  PYTHONPATH="${DEST}/lib/python3.5/site-packages" "${DEST}/bin/python3" bootstrap.py
QEMU_LD_PREFIX="${HOME}/xtools/toolchain/${DROBO}/${HOST}/libc" \
  PYTHONPATH="${DEST}/lib/python3.5/site-packages" "${DEST}/bin/python3" setup.py \
  build --executable="${DEST}/bin/python3" \
  install --prefix="${DEST}" --force
for f in {easy_install,easy_install-3.5}; do
  sed -i -e "1 s|^.*$|#!${DEST}/bin/python3|g" "${DEST}/bin/$f"
done
popd
}

### PIP ###
_build_pip() {
# setup qemu static for this one:
# https://wiki.debian.org/QemuUserEmulation
# apt-get install binfmt-support qemu-user-static
# http://nairobi-embedded.org/qemu_usermode.html#qemu_ld_prefix
# export QEMU_LD_PREFIX="${HOME}/xtools/toolchain/${DROBO}/${HOST}/libc"

local VERSION="20.2.2"
local FOLDER="pip-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="https://github.com/pypa/pip/archive/${VERSION}.tar.gz"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
QEMU_LD_PREFIX="${HOME}/xtools/toolchain/${DROBO}/${HOST}/libc" \
  PYTHONPATH="${DEST}/lib/python3.5/site-packages" "${DEST}/bin/python3" setup.py \
  build --executable="${DEST}/bin/python3" \
  install --prefix="${DEST}" --force
for f in {pip,pip3,pip3.5}; do
  sed -i -e "1 s|^.*$|#!${DEST}/bin/python3|g" "${DEST}/bin/$f"
done
popd
}

### netifaces ###
_build_netifaces() {
# setup qemu static for this one:
# https://wiki.debian.org/QemuUserEmulation
# apt-get install binfmt-support qemu-user-static
# http://nairobi-embedded.org/qemu_usermode.html#qemu_ld_prefix
# export QEMU_LD_PREFIX="${HOME}/xtools/toolchain/${DROBO}/${HOST}/libc"

local VERSION="0.10.9"
local FOLDER="netifaces-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="https://github.com/al45tair/netifaces/archive/release_0_10_9.tar.gz"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
QEMU_LD_PREFIX="${HOME}/xtools/toolchain/${DROBO}/${HOST}/libc" \
  PYTHONPATH="${DEST}/lib/python3.5/site-packages" "${DEST}/bin/python3" setup.py \
  build --executable="${DEST}/bin/python3" \
  install --prefix="${DEST}" --force
popd
}

### pycryptodome ###
_build_pycryptodome() {
# setup qemu static for this one:
# https://wiki.debian.org/QemuUserEmulation
# apt-get install binfmt-support qemu-user-static
# http://nairobi-embedded.org/qemu_usermode.html#qemu_ld_prefix
# export QEMU_LD_PREFIX="${HOME}/xtools/toolchain/${DROBO}/${HOST}/libc"

local VERSION="3.9.8"
local FOLDER="pycryptodome-${VERSION}"
local FILE="${FOLDER}.tar.gz"
local URL="https://files.pythonhosted.org/packages/4c/2b/eddbfc56076fae8deccca274a5c70a9eb1e0b334da0a33f894a420d0fe93/pycryptodome-3.9.8.tar.gz"

_download_tgz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
QEMU_LD_PREFIX="${HOME}/xtools/toolchain/${DROBO}/${HOST}/libc" \
  PYTHONPATH="${DEST}/lib/python3.5/site-packages" "${DEST}/bin/python3" setup.py \
  build --executable="${DEST}/bin/python3" \
  install --prefix="${DEST}" --force
popd
}

### CERTIFICATES ###
_build_certificates() {
# update CA certificates on a Debian/Ubuntu machine:
# sudo update-ca-certificates
cp -vf /etc/ssl/certs/ca-certificates.crt "${DEST}/etc/ssl/certs/"
ln -vfs certs/ca-certificates.crt "${DEST}/etc/ssl/cert.pem"
}

### BUILD ###
_build() {
  _build_zlib
  _build_bzip
  _build_openssl
  _build_ncurses
  _build_sqlite
  _build_libffi
  _build_expat
  _build_python
  _build_setuptools
  _build_pip
  _build_netifaces
  _build_pycryptodome
  _build_certificates
  _package
}
