// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDebtMarket {
   function getLoanDetail(address _borrower, uint _nftTokenId) external view returns(uint, uint256, uint256, uint256, uint256, uint256);
   function getLoanStatus(address _borrower, uint _nftTokenId) external view returns(uint256);
}

contract DebtMarket is IDebtMarket, ERC1155, Ownable {
    uint private count;

    // Constants
    uint256 public constant OPEN = 0;
    uint256 public constant CLOSE = 1;
    uint256 public constant ARRANGER = 2;
    uint256 public constant BORROWER = 3;
    
    struct Loan {
        uint fracTokenId;
        uint256 debtAmount;
        uint256 rate;
        uint256 dueDate;
        uint256 issueDate;
        uint256 closeDate;
        uint256 party;
        uint256 status;
    }

    // Investor -> NFT ID -> Amount Invested
    mapping (address => mapping (uint => uint256)) public investors;
    
    mapping (address => mapping (uint => Loan)) public shelf;

    // Events
    event Issue(uint indexed tokenId_);
    event Close(uint indexed loan_);
    event LoanUpdated(uint indexed tokenId_);

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
            uint256 _fracTokenId, 
            uint256 _debtAmount,
            uint256 _rate,
            uint256 _dueDate
    ) public onlyOwner{
        require(_fracTokenId != count, "DebtMarket: Fractional token count has matched NFT count");
        
        address operator = _msgSender();
        
        // Mint NFT against the asset such as invoice, warehouse receipt, letter of credit etc.
        _mint(operator, count, 1, "");

        shelf[_borrower][count].fracTokenId = _fracTokenId;
        shelf[_borrower][count].debtAmount = _debtAmount;
        shelf[_borrower][count].rate = _rate;
        shelf[_borrower][count].dueDate = _dueDate;
        shelf[_borrower][count].issueDate = block.timestamp;
        shelf[_borrower][count].party = _party;
        shelf[_borrower][count].status = OPEN;

        emit Issue(count);
        count += 1; // can't overflow, not enough gas in the world to pay for 2**256 nfts.
    }

    function updateLoan(
            uint256 _party,
            address _borrower,
            uint256 _fracTokenId, 
            uint256 _debtAmount,
            uint256 _rate,
            uint256 _dueDate,
            uint _nftTokenId
    ) public onlyOwner{
        require(_fracTokenId != _nftTokenId, "DebtMarket: Fractional token id has matched NFT Token Id");

        shelf[_borrower][_nftTokenId].fracTokenId = _fracTokenId;
        shelf[_borrower][_nftTokenId].debtAmount = _debtAmount;
        shelf[_borrower][_nftTokenId].rate = _rate;
        shelf[_borrower][_nftTokenId].dueDate = _dueDate;
        shelf[_borrower][_nftTokenId].party = _party;
        shelf[_borrower][_nftTokenId].status = OPEN;

        emit LoanUpdated(_nftTokenId);
    }

    function close(address _borrower, uint _nftTokenId) public onlyOwner{
        shelf[_borrower][_nftTokenId].closeDate = block.timestamp;
        shelf[_borrower][_nftTokenId].status = CLOSE;
    }

    function getLoanDetail(address _borrower, uint _nftTokenId) external view override returns(uint, uint256, uint256, uint256, uint256, uint256){
        return (
                shelf[_borrower][_nftTokenId].fracTokenId,
                shelf[_borrower][_nftTokenId].debtAmount, 
                shelf[_borrower][_nftTokenId].rate, 
                shelf[_borrower][_nftTokenId].dueDate, 
                shelf[_borrower][_nftTokenId].issueDate,
                shelf[_borrower][_nftTokenId].party
        );
    }

    function getLoanStatus(address _borrower, uint _nftTokenId) external view override returns(uint256){
        return shelf[_borrower][_nftTokenId].status;
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