#!/bin/sh
PWD=`pwd`
OS="alpine"
IMAGE="multistage"

for arg in "$@"; do
  case $arg in
      "--image="* )
         IMAGE="${arg#*=}";;
      "--os="* )
         OS="${arg#*=}";;
      "--glibc" )
        WITH_MUSL="--with-glibc";;
      "--with-diff" )
         WITH_DIFF="--with-diff";;
      "--metrics" )
        METRICS="--metrics";;
      "--bdb-version="* )
         BDB_VERSION="--bdb-version=${arg#*=}";;
      "-h" )
         echo "$0 <options>"
         echo "\t--os=[alpine]\t OS to use: alpine | debian"
         echo "\t--image=[multistage]\t Dockerfile to Build: multistage | binary | binary-image"
         echo "\t--glibc\t\tBuild binaries with GLIBC"
         echo "\t--with-diff\t\tBuild BTC without a wallet/some RPC commands"
         echo "\t--metrics\t\t\tBuild BTC from 'statoshi' fork: https://github.com/jlopp/statoshi"
         echo "\t--bdb-version=[db-4.8.30.NC]\tVersion of Berkeley DB to use [ default: db-4.8.30.NC ]"
         exit 0;;
  esac
done
OPTS="$WITH_MUSL $WITH_DIFF $METRICS $BDB_VERSION"
echo "Building Bitcoin with options: $OPTS"

echo "Image: $IMAGE"
#docker run -d -v ${PWD}:/srv --name bitcoin_builder alpine sh -x /srv/make_binary_dist.sh ${OPTS}
#docker logs -f bitcoin_builder
