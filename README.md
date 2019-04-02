# Dockerized bitcoind consensus node

This is intended as an easy way to run a bitcoin full node without requiring the manual steps normally associated with running a full node.Docker makes a lot of things easier **but not always the most secure**.  This is not meant a secure way to run a `bitcoind` node. Nor is it recommended that you enable a wallet on this buildYou should treat this a consensus node **only**, running release-candidate bitcoind.

>>**NOTE**: Do **NOT** enable a wallet on this container.


### About the sources

This build is based on the [bitcoin master branch](https://github.com/bitcoin/bitcoin), since we had no interest in using it for mining or for a wallet. We also forked the [bitcoin core repo](https://github.com/blockstackpbc/bitcoin/tree/blockstackpbc-custom) - adding some build scripts to automate it, as well as a [diff](https://github.com/blockstackpbc/bitcoin/blob/blockstackpbc-custom/no_rpc.diff) to remove some RPC commands we don't want to expose.


## Component parts

The repository defines several Dockerfiles you use to build and run a bitcoin node. The images consume a binary which is referenced from the Dockerfiles via the `BTC_URL` variable.

### Docker images

Building this in Debian is easy, but also very bloated and defeats the goal of having a lean container that **just** runs `bitcoind`.

| Image | Description |
|------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------|
| [Alpine](https://github.com/blockstackpbc/bitcoin-docker/blob/master/Dockerfile-bitcoind.alpine) | Current image is based on this this. Only official Alpine pkgs were used in this image (along with a binary 'bitcoind' download). |
| [Alpine with glibc](https://github.com/blockstackpbc/bitcoin-docker/blob/master/Dockerfile-bitcoind) | This was the initial test to see if this idea would work. Runs bitcoin from a `https://bitcoin.org` binary download. |
| [Debian](https://github.com/blockstackpbc/bitcoin-docker/blob/master/Dockerfile-bitcoind.debian) | Uses the same type of build process as the core Alpine image, this is based off of 'debian:latest' |

### bitcoind binary

The binary download is built outside of this repo, in a [bitcoin core repo](https://github.com/blockstackpbc/bitcoin/tree/blockstackpbc-custom) fork. The binary builds are created via Docker containers for Alpine and for Debian. These binary builds:

* apply the [diff](https://github.com/blockstackpbc/bitcoin/blob/blockstackpbc-custom/no_rpc.diff)* 
* install required dependencies
* build the binarie

A final, additional script creates the 'tar.gz' file containing the binary from which a release is created in the forked repo.

The Dockerfiles in this `bitcoin` repository downloads the OS-appropriate `tar.gz` file (`BTC_URL`). 


## Configure and Run the images

In the `/configs/bitcoin` directory, are two `.conf` files. The `bitcoin.conf` file sets some sane defaults on a small VM (The VM will take a while to fully sync). The `bitcoin.conf` file is default sample. 

To build the image:

1. Modify the `conf` to your liking.
2. Mount the configuration file and the data into the container.

    ```
      docker run -d \
        -v <working dir>/configs/bitcoin/bitcoin.conf:/etc/bitcoin/bitcoin.conf \
        -v /data/bitcoin:/root/.bitcoin \
      blockstack/bitcoind:alpine
    ```

Example: To mount the configuration file without the data:

```
docker run -d \
  -v <working dir>/configs/bitcoin/bitcoin.conf:/etc/bitcoin/bitcoin.conf \
blockstack/bitcoind:alpine
```


Example: Full including port and environment specification

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
Also included in this repo are some 'packer' files to build machine images, as well as some scripts for 'haproxy'.

For 'packer', the ignition files just setup CoreOS with some services for `btc`, `haproxy`, and a few helper services ( like a 'docker' network ). Feel free to modify to your liking.

The `haproxy` script automatically retrieves 'hosts' with a label of `role: bitcoind` and  the public ip. Then using a template, the script rewrites the 'haproxy' config adding in any more hosts it finds. Finally, it does a haproxy container restart on the VM.

Neither `btc` or `haproxy` are needed to run the containers, but they're there in case anyone can get some use out of them.
