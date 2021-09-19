const DebtMarket = artifacts.require("DebtMarket");
const Lender = artifacts.require("Lender");
const DocumentStorage = artifacts.require("DocumentStorage");

module.exports = function(deployer) {
  deployer.deploy(DebtMarket).then(function() {
    return deployer.deploy(Lender, DebtMarket.address);
  });

  deployer.deploy(DocumentStorage);
};
