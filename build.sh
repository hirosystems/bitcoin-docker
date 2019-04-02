#/bin/sh
echo "Building Dockerfile-python.gcp"
docker build -f Dockerfile-python.gcp -t quay.io/blockstack/bitcoind:python.gcp -t blockstack/bitcoind:python.gcp .
docker push quay.io/blockstack/bitcoind:python.gcp
docker push blockstack/bitcoind:python.gcp
echo ""
echo ""
echo "Building Dockerfile-bitcoind.alpine"
docker build -f Dockerfile-bitcoind.alpine -t quay.io/blockstack/bitcoind:alpine -t blockstack/bitcoind:alpine .
docker push quay.io/blockstack/bitcoind:alpine
docker push blockstack/bitcoind:alpine
echo ""
echo ""
echo "Building Dockerfile-bitcoind.debian"
docker build -f Dockerfile-bitcoind.debian -t quay.io/blockstack/bitcoind:debian -t blockstack/bitcoind:debian .
docker push quay.io/blockstack/bitcoind:debian
docker push blockstack/bitcoind:debian
echo ""
echo ""
echo "Building Bitcore"
git clone https://github.com/bitpay/bitcore .
cp -R Dockerfile-bitcore bitcore/Dockerfile-bitcore.alpine
cd bitcore
docker build -f Dockerfile-bitcore.alpine -t quay.io/blockstack/bitcoind:bitcore -t blockstack/bitcoind:bitcore .
docker push quay.io/blockstack/bitcoind:bitcore
docker push blockstack/bitcoind:bitcore
cd .. && rm -rf bitcore
echo "Done"
echo ""
