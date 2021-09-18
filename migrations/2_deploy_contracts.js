const DebtMarket = artifacts.require("DebtMarket");
const Lender = artifacts.require("Lender");

module.exports = function(deployer) {
  deployer.deploy(DebtMarket).then(function() {
    return deployer.deploy(Lender, DebtMarket.address);
  });
};
