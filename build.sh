#/bin/sh
echo "Building Dockerfile-gcp"
docker build -f Dockerfile-gcp -t quay.io/blockstack/bitcoind:python.gcp -t bitcoind:python.gcp .
docker push quay.io/blockstack/bitcoind:python.gcp
#docker push blockstack/bitcoind:python.gcp
echo ""
echo ""
echo "Building Dockerfile-bitcoind"
docker build -f Dockerfile-bitcoind -t quay.io/blockstack/bitcoind:latest -t blockstack/bitcoind:latest .
docker push quay.io/blockstack/bitcoind:latest
# docker push blockstack/bitcoind:latest
echo ""
echo ""
echo "Building Dockerfile-bitcoind.alpine"
docker build -f Dockerfile-bitcoind.alpine -t quay.io/blockstack/bitcoind:alpine -t blockstack/bitcoind:alpine .
docker push quay.io/blockstack/bitcoind:alpine
# docker push blockstack/bitcoind:alpine
echo ""
echo ""
echo "Building Dockerfile-bitcoind.debian"
docker build -f Dockerfile-bitcoind.debian -t quay.io/blockstack/bitcoind:debian -t blockstack/bitcoind:debian .
docker push quay.io/blockstack/bitcoind:debian
# docker push blockstack/bitcoind:alpine
echo "Done"
echo ""
