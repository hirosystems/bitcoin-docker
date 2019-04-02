# Dockerized bitcoind consensus node

This is intended as an easy way to run a bitcoin full node without requiring the manual steps normally associated with running a full node.Docker makes a lot of things easier **but not always the most secure**.  This is not meant a secure way to run a `bitcoind` node. Nor is it recommended that you enable a wallet on this buildYou should treat this a consensus node **only**, running release-candidate bitcoind.

>>**NOTE**: Do **NOT** enable a wallet on this container.


## Sources incorporeated

This build is based on the [bitcoin master branch](https://github.com/bitcoin/bitcoin), since we had no interest in using it for mining or for a wallet. We also forked the [bitcoin core repo](https://github.com/blockstackpbc/bitcoin/tree/blockstackpbc-custom) - adding some build scripts to automate it, as well as a [diff](https://github.com/blockstackpbc/bitcoin/blob/blockstackpbc-custom/no_rpc.diff) to remove some RPC commands we don't want to expose.




### Docker Images
Building this in Debian is easy, but also very bloated and defeats the goal of having a lean container that **just** runs `bitcoind`.

|  |  |
|------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| [Alpine](https://github.com/blockstackpbc/bitcoin-docker/blob/master/Dockerfile-bitcoind.alpine) | Current image is based on this this. Only official Alpine pkgs were used in this image (along with a binary 'bitcoind' download). |
| [Alpine with glibc](https://github.com/blockstackpbc/bitcoin-docker/blob/master/Dockerfile-bitcoind) | This was the initial test to see if this idea would work. Runs bitcoin from a `https://bitcoin.org` binary download. |
| [Debian](https://github.com/blockstackpbc/bitcoin-docker/blob/master/Dockerfile-bitcoind.debian) | Uses the same type of build process as the core Alpine image, this is based off of 'debian:latest' |

### bitcoind
The binary download is generated outside of this repo, in the forked [bitcoin core repo](https://github.com/blockstackpbc/bitcoin/tree/blockstackpbc-custom).

These builds are also done on Docker containers for Alpine and for Debian.

Essentially we're just applying the [diff](https://github.com/blockstackpbc/bitcoin/blob/blockstackpbc-custom/no_rpc.diff), installing required dependencies, and building the binaries. There is also an additional script used to create the tar.gz containing the binary files which we then create a release of in our forked repo.

This is the tar.gz file that is downloaded in the Dockerfiles - one for Alpine which is built on Alpine, and one for Debian built on Debian.


### Configuring
in the `/configs/bitcoin` directory, you'll see 2 .conf files. Once `bitcoin.conf` is setup for some sane defaults on a small VM (it'll take a while to fully sync), along with the default bitcoin.conf sample.

It's recommened that you modify the conf to your liking, then mount that into the container:
```
  docker run -d \
    -v <working dir>/configs/bitcoin/bitcoin.conf:/etc/bitcoin/bitcoin.conf \
  blockstack/bitcoind:alpine
```
Likewise, it's also recommended that you mount where the data is stored:
```
  docker run -d \
    -v <working dir>/configs/bitcoin/bitcoin.conf:/etc/bitcoin/bitcoin.conf \
    -v /data/bitcoin:/root/.bitcoin \
  blockstack/bitcoind:alpine
```
Full Example:
```
/usr/bin/docker run -d \
  --net=bitcoind \
  --memory=2560m \
  -p 38332:8332 \
  -p 38333:8333 \
  -p 58333:28332 \
  --expose 38332 \
  --expose 38333 \
  --expose 58333 \
  -e BTC_CONF=/etc/bitcoin/bitcoin.conf \
  -e BTC_DATA=/root/.bitcoin \
  -e BTC_PID=/run/bitcoind.pid \
  -v /bitcoind/configs/bitcoin/bitcoin.conf:/etc/bitcoin/bitcoin.conf \
  -v /data/bitcoin:/root/.bitcoin \
  --name bitcoin_core \
  blockstack/bitcoind:alpine \
/usr/local/bin/bitcoind -daemon -conf=/etc/bitcoin/bitcoin.conf -pid=/run/bitcoind.pid -datadir=/root/.bitcoin
```


### Extras
Also included in this repo are some packer files to build machine images, as well as some scripts for haproxy.

For packer, the ignition files essentially just setup CoreOS with some services for `btc`, `haproxy`, and a few helper services ( like a docker network ). Feel free to modify to your liking.

The haproxy script is created to automatically retrieve hosts with a label of `role: bitcoind`, retrieve the public ip, and then using a template it will rewrite the haproxy config adding in any more hosts it finds....followed by an haproxy container restart on the VM.

Neither of these are needed to run the containers, but they're there in case anyone can get some use out of them.
