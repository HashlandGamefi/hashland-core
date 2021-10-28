module.exports = {
  apps: [
    {
      name: 'alert',
      script: 'npx',
      args: 'hardhat run --network testnet scripts/alert.ts',
      autorestart: true,
      max_restarts: 5,
      min_uptime: '10s',
      restart_delay: 5000,
      out_file: 'logs/alert/normal.log',
      error_file: 'logs/alert/error.log',
      combine_logs: true,
    },
  ]
};