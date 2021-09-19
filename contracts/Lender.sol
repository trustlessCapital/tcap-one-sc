// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


interface IDebtMarket {
   function getLoanDetail(address _borrower, uint _tokenId) external view returns(uint256, uint256, uint256, uint256, uint256, address);
   function getLoanStatus(address _borrower, uint _tokenId) external view returns(uint256);
}

interface ILender {
   function getInvestment(address _investor, uint _tokenId) external view returns(uint256, uint256, uint256, bool);
}

contract Lender is ILender, ERC1155, Ownable {
    using SafeMath for uint256;
    // Role status of investors

    mapping (address => bool) whitelisted;

    address public debtMarket;
    uint256 public constant ERC20TOKENID = 833217;

    // Investment Types
    uint256 public constant CRYPTO = 0;
    uint256 public constant FIAT = 1;
    
    
    struct Investment {
        uint256 amountInvested;
        uint256 redeemedAmount;
        uint256 investmentType;
        bool redeemed;
    }

    event Invested(uint indexed tokenId_, uint256 issueTime);

    // NFT ID -> Total Amount Invested
    mapping (uint => uint256) totalAmountInvested;

    // Investor -> NFT ID -> Amount Invested
    mapping (address => mapping (uint => Investment)) investors;
    constructor(address _debtMarket) public ERC1155("https://tcap.one/api/asset/{id}.json"){
        debtMarket = _debtMarket;
    }

    function invest(address _borrower, address _investor, uint256 _nftTokenId, uint256 _investmentType, uint256 _amountInvested) public {
        require(isWhitelisted(_investor), "Investor is not whitelisted");
        (uint256 debtAmount, uint256 rate, uint256 dueDate, uint256 issueDate, uint256 party, address anchor) = IDebtMarket(debtMarket).getLoanDetail(_borrower, _nftTokenId);
        require( _investmentType == 0 || _investmentType == 1, "Lender: Investment type should be fiat or crypto");
        emit Invested(_nftTokenId, block.timestamp);
        require( block.timestamp < dueDate, "Lender: Due date should be greater than blockchain time");
        require(  totalAmountInvested[_nftTokenId] < debtAmount, "Lender: Total investment amount should be less than Debt Amount");

        uint256 remainingLoanReq = debtAmount.sub(totalAmountInvested[_nftTokenId]);
        require(remainingLoanReq>= _amountInvested,"Investment amount should less than or equals to remaining loan requirement");

        _mint(_investor, ERC20TOKENID, _amountInvested, "");
        uint256 amountInvested = investors[_investor][_nftTokenId].amountInvested;
        amountInvested = amountInvested.add(_amountInvested);
    
        investors[_investor][_nftTokenId].amountInvested = amountInvested;
        investors[_investor][_nftTokenId].investmentType = _investmentType;
        investors[_investor][_nftTokenId].redeemedAmount = 0;
        investors[_investor][_nftTokenId].redeemed = false;

        totalAmountInvested[_nftTokenId] = totalAmountInvested[_nftTokenId].add(amountInvested);
    }

    function redeem(address _borrower, address _investor, uint256 _nftTokenId, uint256 _redeemAmount) public {
        require(isWhitelisted(_investor), "Investor is not whitelisted");
        (uint256 debtAmount, uint256 rate, uint256 dueDate, uint256 issueDate, uint256 party, address anchor) = IDebtMarket(debtMarket).getLoanDetail(_borrower, _nftTokenId);
        uint256 loanStatus = IDebtMarket(debtMarket).getLoanStatus(_borrower, _nftTokenId);
        require(loanStatus == 0, "Loan is not open");
        require( _redeemAmount <= investors[_investor][_nftTokenId].amountInvested, "Lender: Can not redeem more than invested");
        require( dueDate < block.timestamp, "Lender: Due date should be greater than block time");
        
        _burn(_investor, ERC20TOKENID, _redeemAmount);

        uint256 redeemAmount = investors[_investor][_nftTokenId].redeemedAmount;
        redeemAmount = redeemAmount.add(_redeemAmount);

        investors[_investor][_nftTokenId].redeemedAmount = redeemAmount;

        if( redeemAmount ==  investors[_investor][_nftTokenId].amountInvested){
            investors[_investor][_nftTokenId].redeemed = true;
        }
    }

    function getInvestment(address _investor, uint _nftTokenId) external view override returns(uint256, uint256, uint256, bool) {
        return (
            investors[_investor][_nftTokenId].amountInvested,
            investors[_investor][_nftTokenId].investmentType,
            investors[_investor][_nftTokenId].redeemedAmount,
            investors[_investor][_nftTokenId].redeemed
        );
    }

    function getLoanInfo(address _borrower, uint _nftTokenId) public view returns( uint256, uint256, uint256, uint256, uint256){
        (uint256 debtAmount, uint256 rate, uint256 dueDate, uint256 issueDate, uint256 party, address anchor) = IDebtMarket(debtMarket).getLoanDetail(_borrower, _nftTokenId);
        return (
                debtAmount, 
                rate, 
                dueDate, 
                issueDate,
                party
        );
    }

    function whitelist(address _investor) public onlyOwner{
        require(_investor != address(0), "Lender: Investor has zero address");
        whitelisted[_investor] = true;
    }

    function blacklist(address _investor) public onlyOwner{
        require(_investor != address(0), "Lender: Investor has zero address");
        whitelisted[_investor] = false;
    }

    function isWhitelisted(address _investor) public view returns(bool){
        return whitelisted[_investor];
    }

    function transferAdminOwnership(address newAdmin) public onlyOwner{
        require(newAdmin != address(0), "Lender: transfer ownership to the zero address");
        transferOwnership(newAdmin);
    }

    function getAdmin() public view returns(address){
        return owner();
    }
}