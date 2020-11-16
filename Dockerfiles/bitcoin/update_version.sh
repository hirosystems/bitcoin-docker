#!/bin/sh
LOCAL_VERSION="VERSION"
REMOTE_VERSION="https://raw.githubusercontent.com/bitcoin/bitcoin/master/configure.ac"
TEMP_FILE="/tmp/configure.ac"

curl -s $REMOTE_VERSION -o $TEMP_FILE
if [ -f $TEMP_FILE ]; then
  MAJOR=$(grep "define(_CLIENT_VERSION_MAJOR" $TEMP_FILE  | awk '{print $2}' | tr -d \))
  MINOR=$(grep "define(_CLIENT_VERSION_MINOR" $TEMP_FILE  | awk '{print $2}' | tr -d \))
  REVISION=$(grep "define(_CLIENT_VERSION_REVISION" $TEMP_FILE  | awk '{print $2}' | tr -d \))
  BUILD=$(grep "define(_CLIENT_VERSION_BUILD" $TEMP_FILE  | awk '{print $2}' | tr -d \))
  RC=$(grep "define(_CLIENT_VERSION_RC" $TEMP_FILE  | awk '{print $2}' | tr -d \))
else
  exit 3
fi
BTC_VERSION="${MAJOR}.${MINOR}.${REVISION}.${BUILD}.${RC}"
echo $BTC_VERSION > $LOCAL_VERSION
rm -f $TEMP_FILE
