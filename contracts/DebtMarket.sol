// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IDebtMarket {
   function getLoanDetail(address _borrower, uint _nftTokenId) external view returns(uint256, uint256, uint256, uint256, uint256, address);
   function getLoanStatus(address _borrower, uint _nftTokenId) external view returns(uint256);
}

contract DebtMarket is IDebtMarket, ERC1155, Ownable {
    using SafeMath for uint256;
    uint private count;
    uint256 public constant FRAC_ERC20_TOKENID = 833217;

    // Constants
    uint256 public constant OPEN = 0;
    uint256 public constant CLOSE = 1;
    uint256 public constant ARRANGER = 2;
    uint256 public constant BORROWER = 3;
    
    struct Loan {
        uint256 debtAmount;
        uint256 rate;
        uint256 dueDate;
        uint256 issueDate;
        uint256 closeDate;
        uint256 party;
        uint256 status;
        uint256 repayAmount;
        uint256 borrowedAmount;
        address anchor;
    }

    // Investor -> NFT ID -> Amount Invested
    mapping (address => mapping (uint => uint256)) public investors;
    // Borrower -> NFT ID -> Issued loan
    mapping (address => mapping (uint => Loan)) public shelf;

    // Events
    event Issue(uint indexed tokenId_);
    event Close(uint indexed loan_);
    event LoanUpdated(uint indexed tokenId_);
    event Borrow(uint indexed tokenId_);
    event Repay(uint indexed tokenId_);

    constructor() public ERC1155("https://tcap.one/api/asset/{id}.json") {
        count = 1;
    }

    function transferAdminOwnership(address newAdmin) public onlyOwner{
        require(newAdmin != address(0), "DebtMarket: transfer ownership to the zero address");
        transferOwnership(newAdmin);
    }

    function getAdmin() public view returns(address){
        return owner();
    }

    function getNFTCount() public view returns (uint){
        return count-1;
    }

    function issue(
            uint256 _party,
            address _borrower,
            uint256 _debtAmount,
            uint256 _rate,
            uint256 _dueDate,
            address _anchor
    ) public onlyOwner{
        require(FRAC_ERC20_TOKENID != count, "DebtMarket: Fractional token count has matched NFT count");
        
        address operator = _msgSender();
        
        // Mint NFT against the asset such as invoice, warehouse receipt, letter of credit etc.
        _mint(operator, count, 1, "");

        shelf[_borrower][count].debtAmount = _debtAmount;
        shelf[_borrower][count].rate = _rate;
        shelf[_borrower][count].dueDate = _dueDate;
        shelf[_borrower][count].issueDate = block.timestamp;
        shelf[_borrower][count].party = _party;
        shelf[_borrower][count].anchor = _anchor;

        emit Issue(count);
        count += 1; // can't overflow, not enough gas in the world to pay for 2**256 nfts.
    }

    function updateLoan(
            uint256 _party,
            address _borrower,
            uint256 _debtAmount,
            uint256 _rate,
            uint256 _dueDate,
            uint _nftTokenId,
            address _anchor
    ) public onlyOwner{
        require(FRAC_ERC20_TOKENID != _nftTokenId, "DebtMarket: Fractional token id has matched NFT Token Id");

        shelf[_borrower][_nftTokenId].debtAmount = _debtAmount;
        shelf[_borrower][_nftTokenId].rate = _rate;
        shelf[_borrower][_nftTokenId].dueDate = _dueDate;
        shelf[_borrower][_nftTokenId].party = _party;
        shelf[_borrower][_nftTokenId].status = OPEN;
        shelf[_borrower][_nftTokenId].anchor = _anchor;

        emit LoanUpdated(_nftTokenId);
    }

    function close(address _borrower, uint _nftTokenId) public onlyOwner{
        shelf[_borrower][_nftTokenId].closeDate = block.timestamp;
        shelf[_borrower][_nftTokenId].status = CLOSE;
    }

    function getLoanDetail(address _borrower, uint _nftTokenId) external view override returns( uint256, uint256, uint256, uint256, uint256, address){
        return (
                shelf[_borrower][_nftTokenId].debtAmount, 
                shelf[_borrower][_nftTokenId].rate, 
                shelf[_borrower][_nftTokenId].dueDate, 
                shelf[_borrower][_nftTokenId].issueDate,
                shelf[_borrower][_nftTokenId].party,
                shelf[_borrower][_nftTokenId].anchor
        );
    }

    function getLoanStatus(address _borrower, uint _nftTokenId) external view override returns(uint256){
        return shelf[_borrower][_nftTokenId].status;
    }

    function getBorrowRepayDetail(address _borrower, uint _nftTokenId) external view returns(uint256, uint256){
        return (shelf[_borrower][_nftTokenId].borrowedAmount, shelf[_borrower][_nftTokenId].repayAmount);
    }

    // Borrowing
    // starts the borrow process of a loan
    // informs the system of the requested amount
    // interest accumulation starts with this method
    function borrow(address _borrower, uint _nftTokenId, uint256 _amount) public onlyOwner{
        require(shelf[_borrower][_nftTokenId].status == OPEN, "Loan is closed");
        uint256 borrowedAmount = shelf[_borrower][_nftTokenId].borrowedAmount;
        require((_amount + borrowedAmount) <= shelf[_borrower][_nftTokenId].debtAmount, "DebtMarket: Already borrowed.");
        borrowedAmount = borrowedAmount.add(_amount);
        shelf[_borrower][_nftTokenId].borrowedAmount = borrowedAmount;
        emit Borrow(_nftTokenId);
    }

    // repays the entire or partial debt of a loan
    function repay(address _borrower, uint _nftTokenId, uint256 _amount) public onlyOwner{
        require(_amount > 0, "DebtMarket: Repay amount is zero");
        require(shelf[_borrower][_nftTokenId].status == OPEN, "DebtMarket: Loan is closed");

        uint256 borrowedAmount = shelf[_borrower][_nftTokenId].borrowedAmount;
        uint256 repayAmount = shelf[_borrower][_nftTokenId].repayAmount;
        
        require(repayAmount < borrowedAmount, "DebtMarket: Loan is fully repaid");
        require(repayAmount.add(_amount) <= borrowedAmount, "DebtMarket: Repay amount higher than the debt");

        repayAmount = repayAmount.add(_amount);
        shelf[_borrower][_nftTokenId].repayAmount = repayAmount;

        emit Repay(_nftTokenId);
    }
    /**
    * @notice Will self-destruct the contract
    * @dev This will be used if a vulnerability is discovered to halt an attacker
    * @param _recipient Address that will receive stuck ETH, if any
    */
    function NUKE(address payable _recipient) external onlyOwner {
        selfdestruct(_recipient);
    }
}