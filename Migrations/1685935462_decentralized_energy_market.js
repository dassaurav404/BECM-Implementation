const DecentralizedEnergyMarket = artifacts.require('DecentralizedEnergyMarket')

module.exports = function (_deployer) {
  _deployer.deploy(DecentralizedEnergyMarket)
}

