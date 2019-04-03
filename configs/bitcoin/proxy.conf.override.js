module.exports = {
  '/api': {
    target: {
      host: 'bitcore.bitcoind',
      protocol: 'http',
      port: 3000
    },
    secure: false,
    changeOrigin: true,
    logLevel: 'info'
  }
};
