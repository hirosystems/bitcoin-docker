#!/bin/sh -x

NO_RPC=0
STATOSHI=0
WITH_MUSL=1
DEST_DIR="/srv/bitcoind"
BINARY_DEST="/srv/build"
BERKELEYDB_VERSION="db-4.8.30.NC"
BERKELEYDB_PREFIX="/opt/${BERKELEYDB_VERSION}"
OPTS=""
SUFFIX=""

for arg in "$@"; do
  case $arg in
      "-glibc" )
        WITH_MUSL=0;;
      "-norpc" )
         NO_RPC=1;;
      "-statoshi" )
        STATOSHI=1;;
      "-bdb-version="* )
         BERKELEYDB_VERSION="${arg#*=}";;
      "-h" )
         echo "$0 <options>"
         echo " -glibc      Build binaries with GLIBC"
         echo " -norpc      Build BTC without a wallet/some RPC commands"
         echo " -statoshi   Build BTC from 'statoshi' fork: https://github.com/jlopp/statoshi"
         echo " -bdb-version=[db-4.8.30.NC]   Version of Berkeley DB to use [ default: db-4.8.30.NC ]"
         exit 0;;
  esac
done
GIT_REPO="https://github.com/bitcoin/bitcoin"

if [ $STATOSHI -eq 1 ]; then
  GIT_REPO="https://github.com/jlopp/statoshi"
  echo "   - building with statoshi metrics fork"
  SUFFIX="-statoshi"
  NO_RPC=0
fi
if [ $NO_RPC -eq 1 -a $STATOSHI -ne 1 ]; then
  SUFFIX="-norpc"
  echo "   - building with diff file patched"
fi

if [ $WITH_MUSL -eq 0 ]; then
  BINARY_ARCHIVE="glibc-v${BTC_VERSION}${SUFFIX}"
else
  BINARY_ARCHIVE="musl-v${BTC_VERSION}${SUFFIX}"
fi
BINARY_DIR="bitcoin-${BTC_VERSION}"


echo ""
echo ""
echo "Script Vars:"
echo "WITH_MUSL: $WITH_MUSL"
echo "NO_RPC: $NO_RPC"
echo "STATOSHI: $STATOSHI"
echo "BERKELEYDB_VERSION: $BERKELEYDB_VERSION"
echo "SUFFIX: $SUFFIX"
echo "BTC_VERSION: ${BTC_VERSION}${SUFFIX}"
echo "BINARY_DIR: ${BINARY_DIR}"
echo "BINARY_ARCHIVE: $BINARY_ARCHIVE"
echo ""
echo ""

if [ -d ${DEST_DIR} ]; then
  rm -rf ${DEST_DIR}
fi

echo ""
echo "Cloning ${GIT_REPO} into ${DEST_DIR}"
echo ""
if [ $STATOSHI -ne 1 ]; then
  git clone --depth 1 --branch v${BTC_VERSION} ${GIT_REPO} ${DEST_DIR}
else
  git clone ${GIT_REPO} ${DEST_DIR}
fi

# git clone ${GIT_REPO} ${DEST_DIR}
cd ${DEST_DIR}

if [ $NO_RPC -eq 1 ]; then
  OPTS="--disable-wallet"
  cp /srv/no_rpc.diff .
  patch -p1 < no_rpc.diff
  if [ $? -ne 0 ]; then
    echo "Patch Failed...exiting"
    exit 0
  fi
else
  echo ""
  echo "Building Berkeley DB Version:$BERKELEYDB_VERSION"
  echo ""
  wget https://download.oracle.com/berkeley-db/${BERKELEYDB_VERSION}.tar.gz -O /tmp/${BERKELEYDB_VERSION}.tar.gz
  tar -xzf /tmp/${BERKELEYDB_VERSION}.tar.gz -C /tmp/
  sed s/__atomic_compare_exchange/__atomic_compare_exchange_db/g -i /tmp/${BERKELEYDB_VERSION}/dbinc/atomic.h
  mkdir -p ${BERKELEYDB_PREFIX}
  cd /tmp/${BERKELEYDB_VERSION}/build_unix
  ../dist/configure --enable-cxx --disable-shared --with-pic --prefix=${BERKELEYDB_PREFIX}
  make -j4
  make install
  /sbin/ldconfig /usr/lib /lib ${BERKELEYDB_PREFIX}/lib
  BDB_LDFLAGS="-L${BERKELEYDB_PREFIX}/lib/"
  BDB_CPPFLAGS="-I${BERKELEYDB_PREFIX}/include/"
fi

cd ${DEST_DIR}
echo ""
echo "Building BTC Version:$BTC_VERSION${SUFFIX}"
echo ""
echo ""
echo "Running autogen"
echo ""
sh autogen.sh

echo ""
echo "Configuring bitcoin"
echo ""
./configure \
  --enable-util-cli $OPTS \
  --disable-gui-tests \
  --enable-static \
  --disable-tests \
  --without-miniupnpc \
  --disable-shared \
  --with-pic \
  --enable-cxx \
  LDFLAGS="${BDB_LDFLAGS} -static-libstdc++" \
  CPPFLAGS="${BDB_CPPFLAGS} -static-libstdc++"

echo ""
echo "Compiling bitcoin"
echo ""
make STATIC=1

echo ""
echo "Creating Binary dist"
echo ""

if [ -d ${BINARY_DIR} ]; then
  rm -rf ${BINARY_DIR}
fi
if [ -f ${BINARY_DIR}.tar ]; then
  rm -f ${BINARY_DIR}.tar
fi
if [ -f ${BINARY_DIR}.tar.gz ]; then
  rm -f ${BINARY_DIR}.tar.gz
fi
mkdir -p ${BINARY_DIR}/bin
mkdir -p ${BINARY_DIR}/include
mkdir -p ${BINARY_DIR}/share/man/man1
strip src/bitcoind
strip src/bitcoin-cli
strip src/bitcoin-tx
cp -a src/bitcoind ${BINARY_DIR}/bin/
cp -a src/bitcoin-cli ${BINARY_DIR}/bin/
cp -a src/bitcoin-tx ${BINARY_DIR}/bin/
cp -a src/script/bitcoinconsensus.h ${BINARY_DIR}/include/
cp -a doc/man/bitcoin-cli.1 ${BINARY_DIR}/share/man/man1/
cp -a doc/man/bitcoin-tx.1 ${BINARY_DIR}/share/man/man1/
cp -a doc/man/bitcoind.1 ${BINARY_DIR}/share/man/man1/
tar -cf ${BINARY_ARCHIVE}.tar ${BINARY_DIR} && gzip ${BINARY_ARCHIVE}.tar
mkdir ${BINARY_DEST}
mv ${BINARY_ARCHIVE}.tar.gz ${BINARY_DEST}/${BINARY_ARCHIVE}.tar.gz
