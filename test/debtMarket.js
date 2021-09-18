const DebtMarket = artifacts.require("DebtMarket");
const Lender = artifacts.require("Lender");
const DocumentStorage = artifacts.require("DocumentStorage");
var bs58 = require('bs58');

let documentStorage;

beforeEach(async () => {
    documentStorage = await DocumentStorage.new();
});
const ipfsHashes = [
    'QmahqCsAUAw7zMv6P6Ae8PjCTck7taQA6FgGQLnWdKG7U8',
    'Qmb4atcgbbN5v4CDJ8nz5QG5L2pgwSTLd3raDrnyhLjnUH',
];

contract('DebtMarket', (accounts) => {
    it('should have count equals to 0', async () => {
        const debtMarketInstance = await DebtMarket.deployed();
        let count = await debtMarketInstance.getNFTCount()
        assert.equal(count.toNumber(), 0, "count is not 1");
    });

    it('should mint NFT and fractional token while issueing loan', async () => {
        const debtMarketInstance = await DebtMarket.deployed();
        const tokenID = 833217;
        const ARRANGER = 2;
        await debtMarketInstance.issue(ARRANGER, accounts[2], tokenID, 1000, 0, 0);
        let nftCount = await debtMarketInstance.getNFTCount()
        assert.equal(nftCount, 1, "First NFT should have count 1");
    });

    it('should get loans issued to a borrower', async () => {
        const debtMarketInstance = await DebtMarket.deployed();
        const tokenID = 833217;
        const rate = 10;
        const dueDate = Math.round((new Date()).getTime());
        const BORROWER = 3;
        const OPEN = 0;
        await debtMarketInstance.issue(BORROWER, accounts[2], tokenID, 1000, rate, dueDate);
        let nftCount = await debtMarketInstance.getNFTCount()
        assert.equal(nftCount, 2, "NFT should have count 2");

        const loans = await debtMarketInstance.getLoanDetail(accounts[2], nftCount);

        assert.equal(loans[0].toNumber(), tokenID, "Fractional token id should be 833217");
        assert.equal(loans[1].toNumber(), 1000, "Debt amount should be 1000");
        assert.equal(loans[2].toNumber(), rate, "Rate should be 10");
        assert.equal(loans[3].toNumber(), dueDate, "Due date didn't match");
        assert.equal(new Date(loans[4].toNumber() * 1000).toDateString(), new Date().toDateString(), "Incorrect issue date");
        assert.equal(loans[5].toNumber(), BORROWER, "Party should be BORROWER");

        const loanStatus = await debtMarketInstance.getLoanStatus(accounts[2], 2);
        assert.equal(loanStatus.toNumber(), OPEN, "Loan status should be OPEN");
    });

});

contract('Lender', (accounts) => {
    it('should let the investor invest', async () => {
        const lenderInstance = await Lender.deployed();
        const debtMarketInstance = await DebtMarket.deployed();
        const tokenID = 833217;
        const ARRANGER = 2;
        
        let today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);
        const dueDate = Math.round(tomorrow.getTime() / 1000);

        const borrower = accounts[2];
        const investor = accounts[3];
        const debtAmount = 1000;
        const rate = 10;
        const CRYPTO_INVESTOR = 0;
        const investmentAmt = 1000;
        await lenderInstance.whitelist(investor);
        await debtMarketInstance.issue(ARRANGER, borrower, tokenID, debtAmount, rate, dueDate);

        let nftTokenId = await debtMarketInstance.getNFTCount();

        await lenderInstance.invest(borrower, investor, nftTokenId, CRYPTO_INVESTOR, investmentAmt);

        let investment = await lenderInstance.getInvestment(investor, nftTokenId);

        assert.equal(investment[0].toNumber(), investmentAmt, "Amount invested is not matched");
        assert.equal(investment[1].toNumber(), CRYPTO_INVESTOR, "Wrong investor type");
        assert.equal(investment[2].toNumber(), 0, "Redeemed amount should be 0");
        assert.equal(investment[3], false, "No redemeption");
    });

    it('should let the investor redeem', async () => {
        const lenderInstance = await Lender.deployed();
        const debtMarketInstance = await DebtMarket.deployed();
        const tokenID = 833217;
        const ARRANGER = 2;
        
        let today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);
        const dueDate = Math.round(tomorrow.getTime() / 1000);

        const borrower = accounts[2];
        const investor = accounts[3];
        const debtAmount = 1000;
        const rate = 10;
        const CRYPTO_INVESTOR = 0;
        const investmentAmt = 1000;
        await lenderInstance.whitelist(investor);
        await debtMarketInstance.issue(ARRANGER, borrower, tokenID, debtAmount, rate, dueDate);

        let nftTokenId = await debtMarketInstance.getNFTCount();

        await lenderInstance.invest(borrower, investor, nftTokenId, CRYPTO_INVESTOR, investmentAmt);

        let investment = await lenderInstance.getInvestment(investor, nftTokenId);

        assert.equal(investment[0].toNumber(), investmentAmt, "Amount invested is not matched");
        assert.equal(investment[1].toNumber(), CRYPTO_INVESTOR, "Wrong investor type");
        assert.equal(investment[2].toNumber(), 0, "Redeemed amount should be 0");
        assert.equal(investment[3], false, "No redemeption");
        

        // Start redemption

        // Update due date of the loan
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        const newDueDate = Math.round(yesterday.getTime() / 1000);
        await debtMarketInstance.updateLoan(ARRANGER, borrower, tokenID, debtAmount, rate, newDueDate, nftTokenId);
        const loans = await debtMarketInstance.getLoanDetail(borrower, nftTokenId);

        assert.equal(loans[3].toNumber(), newDueDate, "New Due date didn't match");
        const redeemAmt = investmentAmt;
        await lenderInstance.redeem(borrower, investor, nftTokenId, redeemAmt);

        investment = await lenderInstance.getInvestment(investor, nftTokenId);

        assert.equal(investment[0].toNumber(), investmentAmt, "Amount invested is not matched");
        assert.equal(investment[1].toNumber(), CRYPTO_INVESTOR, "Wrong investor type");
        assert.equal(investment[2].toNumber(), redeemAmt, "Redeemed amount should be 0");
        assert.equal(investment[3], true, "Should redeem all the amount");
    });

    it('should let the multiple investors invest and redeem', async () => {
        const lenderInstance = await Lender.deployed();
        const debtMarketInstance = await DebtMarket.deployed();
        const tokenID = 833217;
        const ARRANGER = 2;
        
        let today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);
        const dueDate = Math.round(tomorrow.getTime() / 1000);

        const borrower = accounts[2];
        const investor1 = accounts[3];
        const investor2 = accounts[4];
        const debtAmount = 1000;
        const rate = 10;
        const CRYPTO_INVESTOR = 0;
        const investmentAmt1 = 500;
        const investmentAmt2 = 500;
        const OPEN = 0;
        await lenderInstance.whitelist(investor1);
        await debtMarketInstance.issue(ARRANGER, borrower, tokenID, debtAmount, rate, dueDate);

        let nftTokenId = await debtMarketInstance.getNFTCount();

        await lenderInstance.invest(borrower, investor1, nftTokenId, CRYPTO_INVESTOR, investmentAmt1);

        let investment = await lenderInstance.getInvestment(investor1, nftTokenId);

        assert.equal(investment[0].toNumber(), investmentAmt1, "Amount invested is not matched");
        assert.equal(investment[1].toNumber(), CRYPTO_INVESTOR, "Wrong investor type");
        assert.equal(investment[2].toNumber(), 0, "Redeemed amount should be 0");
        assert.equal(investment[3], false, "No redemeption");


        // Second Investor
        await lenderInstance.whitelist(investor2);
        await lenderInstance.invest(borrower, investor2, nftTokenId, CRYPTO_INVESTOR, investmentAmt2);

        investment = await lenderInstance.getInvestment(investor2, nftTokenId);

        assert.equal(investment[0].toNumber(), investmentAmt2, "Amount invested is not matched");
        assert.equal(investment[1].toNumber(), CRYPTO_INVESTOR, "Wrong investor type");
        assert.equal(investment[2].toNumber(), 0, "Redeemed amount should be 0");
        assert.equal(investment[3], false, "No redemeption");
        

        // Start redemption for the first investor

        // Update due date of the loan
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        const newDueDate = Math.round(yesterday.getTime() / 1000);
        await debtMarketInstance.updateLoan(ARRANGER, borrower, tokenID, debtAmount, rate, newDueDate, nftTokenId);
        const loans = await debtMarketInstance.getLoanDetail(borrower, nftTokenId);

        assert.equal(loans[3].toNumber(), newDueDate, "New Due date didn't match");
        const redeemAmt = investmentAmt1;
        await lenderInstance.redeem(borrower, investor1, nftTokenId, redeemAmt);

        investment = await lenderInstance.getInvestment(investor1, nftTokenId);

        assert.equal(investment[0].toNumber(), investmentAmt1, "Amount invested is not matched");
        assert.equal(investment[1].toNumber(), CRYPTO_INVESTOR, "Wrong investor type");
        assert.equal(investment[2].toNumber(), redeemAmt, "Redeemed amount should be 0");
        assert.equal(investment[3], true, "Should redeem all the amount");

        const loanStatus = await debtMarketInstance.getLoanStatus(borrower, nftTokenId);
        assert.equal(loanStatus.toNumber(), OPEN, "Loan status should be OPEN");

        // Start redemption for the second investor
        await lenderInstance.redeem(borrower, investor2, nftTokenId, redeemAmt);

        investment = await lenderInstance.getInvestment(investor2, nftTokenId);

        assert.equal(investment[0].toNumber(), investmentAmt1, "Amount invested is not matched");
        assert.equal(investment[1].toNumber(), CRYPTO_INVESTOR, "Wrong investor type");
        assert.equal(investment[2].toNumber(), redeemAmt, "Redeemed amount should be 0");
        assert.equal(investment[3], true, "Should redeem all the amount");

    });

    it('should close the loan', async () => {
        const lenderInstance = await Lender.deployed();
        const debtMarketInstance = await DebtMarket.deployed();
        const tokenID = 833217;
        const ARRANGER = 2;
        
        let today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);
        const dueDate = Math.round(tomorrow.getTime() / 1000);

        const borrower = accounts[2];
        const investor = accounts[5];
        const debtAmount = 1000;
        const rate = 10;
        const CRYPTO_INVESTOR = 0;
        const investmentAmt = 1000;
        const CLOSE = 1;
        await debtMarketInstance.issue(ARRANGER, borrower, tokenID, debtAmount, rate, dueDate);

        let nftTokenId = await debtMarketInstance.getNFTCount();
        await lenderInstance.whitelist(investor);
        await lenderInstance.invest(borrower, investor, nftTokenId, CRYPTO_INVESTOR, investmentAmt);

        let investment = await lenderInstance.getInvestment(investor, nftTokenId);

        assert.equal(investment[0].toNumber(), investmentAmt, "Amount invested is not matched");
        assert.equal(investment[1].toNumber(), CRYPTO_INVESTOR, "Wrong investor type");
        assert.equal(investment[2].toNumber(), 0, "Redeemed amount should be 0");
        assert.equal(investment[3], false, "No redemeption");
        

        // Start redemption

        // Update due date of the loan
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        const newDueDate = Math.round(yesterday.getTime() / 1000);
        await debtMarketInstance.updateLoan(ARRANGER, borrower, tokenID, debtAmount, rate, newDueDate, nftTokenId);
        const loans = await debtMarketInstance.getLoanDetail(borrower, nftTokenId);

        assert.equal(loans[3].toNumber(), newDueDate, "New Due date didn't match");
        const redeemAmt = investmentAmt;
        
        await lenderInstance.redeem(borrower, investor, nftTokenId, redeemAmt);

        investment = await lenderInstance.getInvestment(investor, nftTokenId);

        assert.equal(investment[0].toNumber(), investmentAmt, "Amount invested is not matched");
        assert.equal(investment[1].toNumber(), CRYPTO_INVESTOR, "Wrong investor type");
        assert.equal(investment[2].toNumber(), redeemAmt, "Redeemed amount should be 0");
        assert.equal(investment[3], true, "Should redeem all the amount");

        await debtMarketInstance.close(borrower, nftTokenId);
        const loanStatus = await debtMarketInstance.getLoanStatus(borrower, nftTokenId);
        assert.equal(loanStatus.toNumber(), CLOSE, "Loan status should be CLOSE");
    });
});

contract('DocumentStorage', (accounts) => {

    it('should get IPFS hash after setting', async () => {
        const tokenId = 1000;
        await setIPFSHash(tokenId, accounts[0], ipfsHashes[0]);
        expect(await getIPFSHash(tokenId)).to.equal(ipfsHashes[0]);
    });

    it('should set IPFS hash for each address', async () => {
        const tokenIdOne = 1000;
        const tokenIdTwo = 1001;
        await setIPFSHash(tokenIdOne, accounts[0], ipfsHashes[0]);
        await setIPFSHash(tokenIdTwo, accounts[1], ipfsHashes[1]);
    
        expect(await getIPFSHash(tokenIdOne)).to.equal(ipfsHashes[0]);
        expect(await getIPFSHash(tokenIdTwo)).to.equal(ipfsHashes[1]);
    });

    it('should clear IPFS hash after set', async () => {
        const tokenId = 1000;
        await setIPFSHash(tokenId, accounts[0], ipfsHashes[0]);
        expect(await getIPFSHash(tokenId)).to.equal(ipfsHashes[0]);
    
        await documentStorage.ipfsClearEntry(tokenId);
        expect(await getIPFSHash(tokenId)).to.be.a('null');
    });
});

//********************** Helper Methods **********************//

async function setIPFSHash(tokenId, account, hash) {
    const { digest, hashFunction, size } = await getBytes32FromMultiash(hash);
    return documentStorage.setIpfsEntry(tokenId, digest, hashFunction, size, { from: account });
}

async function getBytes32FromMultiash(multihash){
    const decoded = bs58.decode(multihash);
    return {
      digest: `0x${decoded.slice(2).toString('hex')}`,
      hashFunction: decoded[0],
      size: decoded[1],
    };
}

async function getIPFSHash(tokenId) {
    var value = await documentStorage.getIpfsEntry(tokenId);
    return await getMultihashFromBytes32(value[0], value[1].toNumber(), value[2].toNumber());
}

async function getMultihashFromBytes32(digest, hashFunction, size) {
    if (size === 0) return null;
  
    // cut off leading "0x"
    const hashBytes = Buffer.from(digest.slice(2), 'hex');
  
    // prepend hashFunction and digest size
    const multihashBytes = new (hashBytes.constructor)(2 + hashBytes.length);
    multihashBytes[0] = hashFunction;
    multihashBytes[1] = size;
    multihashBytes.set(hashBytes, 2);
    return bs58.encode(multihashBytes);
}