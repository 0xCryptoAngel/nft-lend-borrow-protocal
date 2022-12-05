// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IPikachu.sol";
import "./VerifySignature.sol";

contract Pikachu is IPikachu, VerifySignature, Ownable {
    uint256 constant BLOCK_PER_DAY = 7200;

    AdminSetting public adminSetting;

    mapping (address => Pool) private pools;
    mapping (uint256 => address) public poolOwners;
    // totalPools:: total number of pools
    uint256 public totalPools;

    mapping (address => mapping (address => Loan)) loans;

    modifier onlyCreator(uint256 poolId) {
        require(poolOwners[poolId] == msg.sender);
        _;
    }

    constructor (AdminSetting memory _adminSetting) {
        updateAdminSetting(_adminSetting);
    }

    /// @notice Update system settings
    function updateAdminSetting(AdminSetting memory _adminSetting) onlyOwner public {
        adminSetting = _adminSetting;
    }

    /// @notice Create a new pool with provided information
    function createPool(
        uint256 _loanToValue,
        uint256 _maxAmount,
        InterestType _interestType,
        uint256 _interestStartRate,
        uint256 _interestCapRate,
        uint256 _maxDuration,
        bool _compound,
        address[] memory _collections
    ) external payable {
        require(msg.value >= adminSetting.minDepositAmount, "createPool: Needs more coin to create pool");
        Pool storage newPool = pools[msg.sender];
        require(newPool.status == PoolStatus.None, "createPool: Already exists");
        newPool.loanToValue = _loanToValue;
        newPool.maxAmount = _maxAmount;
        newPool.interestType = _interestType;
        newPool.interestStartRate = _interestStartRate;
        newPool.interestCapRate = _interestCapRate;
        newPool.maxDuration = _maxDuration;
        newPool.compound = _compound;
        newPool.collections = _collections;

        newPool.owner = msg.sender;

        newPool.depositedAmount = msg.value;
        newPool.availableAmount  = msg.value;
        
        newPool.depositedAt = block.timestamp;
        newPool.createdAt = block.timestamp;
        newPool.updatedAt = block.timestamp;

        poolOwners[totalPools] = msg.sender;

        emit CreatedPool(msg.sender, totalPools, newPool.depositedAmount);

        totalPools ++;
    }

    /// @notice update a new pool with provided information
    function updatePool(
        uint256 _loanToValue,
        uint256 _maxAmount,
        InterestType _interestType,
        uint256 _interestStartRate,
        uint256 _interestCapRate,
        uint256 _maxDuration,
        bool _compound,
        address[] memory _collections
    ) external payable {
        Pool storage pool = pools[msg.sender];
        require(pool.status == PoolStatus.Ready, "Invalid Pool to update");
        pool.loanToValue = _loanToValue;
        pool.maxAmount = _maxAmount;
        pool.interestType = _interestType;
        pool.interestStartRate = _interestStartRate;
        pool.interestCapRate = _interestCapRate;
        pool.maxDuration = _maxDuration;
        pool.compound = _compound;
        pool.collections = _collections;
        pool.updatedAt = block.timestamp;
    }

    

    /// @notice Withdraw ETH from pool
    /// @param _amount eth value to withdraw from own pool
    function withdrawFromPool(uint256 _amount) external {
        Pool storage pool = pools[msg.sender];
        require(pool.status == PoolStatus.Ready, "Invalid Pool");
        require(pool.availableAmount >= _amount, "Withdrawal amount exceeds the balance");
        pool.availableAmount -= _amount;
        pool.updatedAt = block.timestamp;
        (bool sent,) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    /// @notice Deposit ETH to pool
    function depositToPool() external payable {
        Pool storage pool = pools[msg.sender];
        require(pool.status == PoolStatus.Ready, "Invalid Pool");
        uint256 _amount = msg.value;
        pool.availableAmount += _amount;
        pool.updatedAt = block.timestamp;
        pool.depositedAmount += _amount;
    }

    function getPoolByOwner (address _owner) public view returns(Pool memory){
        return pools[_owner];
    }
    
    function getPoolById (uint256 _poolId) public view returns (Pool memory) {
        return pools[poolOwners[_poolId]];
    }

    function borrow (address _poolOwner, address _collection, uint256 _tokenId, uint256 _duration, uint256 _amount, bytes memory _signature, uint256 _floorPrice, uint256 _blockNumber) external {
        require(verify(owner(), _collection, _floorPrice, _blockNumber , _signature), "Invalid Transaction");
        require(block.number - _blockNumber <= adminSetting.blockNumberSlippage, "Must have updated floor price!");
        require(_floorPrice >= _amount * 2, "Can't borrow more than 60% of the floor price");

        Pool storage pool = pools[_poolOwner];
        require(pool.status == PoolStatus.Ready, "The pool is not active at the moment");
        require(pool.maxDuration >= _duration, "Request duration is longer than available duration");

        uint256 _i = 0;
        bool validCollection = false;
        for (_i = 0; _i < pool.collections.length; _i++)
            if (pool.collections[_i] == _collection){
                validCollection = true;
                break;
            }
        require(validCollection, "Unacceptable NFT collection");

        require(_floorPrice * pool.loanToValue / 100 >= _amount, "Request amount exceeds the Loan Value");
        require(pool.maxAmount >= _amount, "Request amount exceeds the max loanable amount");
        
        require(loans[_poolOwner][msg.sender].status != LoanStatus.Borrowed, "You have unpaid loan from this pool");
        
        IERC721(_collection).safeTransferFrom(msg.sender, address(this), _tokenId);

        (bool sent,) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send Ether");

        // create loan object
        
        Loan storage newLoan = loans[_poolOwner][msg.sender];

        newLoan.borrower = msg.sender;
        newLoan.amount = _amount;
        newLoan.duration = _duration;
        newLoan.collection = _collection;
        newLoan.tokenId = _tokenId;
        newLoan.status = LoanStatus.Borrowed;
        newLoan.blockNumber = block.number;
        newLoan.timestamp = block.timestamp;
        newLoan.interestType = pool.interestType;
        newLoan.interestStartRate = pool.interestStartRate;
        newLoan.interestCapRate = pool.interestCapRate;

        // update pool
        pool.borrowedAmount += _amount;
        pool.availableAmount -= _amount;
        pool.nftLocked ++;
        pool.totalLoans += _amount;
        pool.lastLoanAt = block.timestamp;

        emit CreatedLoan(pool.owner, newLoan.borrower, newLoan.amount);
    }

    function sqrt(uint256 x) public pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /// @notice Calcuate required amount to repay for loan parameters
    /// @dev The rates are described in basis points
    /// @param _durationSecond The number of seconds that loan has last
    /// @param _interestType Interest rate per day in basis point applied to current loan
    /// @param _amount Loan value in wei
    function calculateRepayAmount(uint256 _durationSecond, InterestType _interestType, uint256 _interestStartRate, uint256 _interestCapRate, uint256 _amount) public pure returns (uint256) {
        uint256 durationInDays = _durationSecond/ 1 days;
        
        if (_interestType == InterestType.Linear) {
            return _amount + _amount * (_interestStartRate + durationInDays * _interestCapRate) / 10000;
        } else {
            return _amount + _amount * _interestStartRate / 10000 + _amount* sqrt(durationInDays * 10000) * _interestCapRate / 1000000;
        }
        
    }

    /// @notice Replay for a loan with Ether and update pool, loan
    /// @dev Explain to a developer any extra details
    /// @param _poolOwner Pool that msg.sender used
    function repay(address _poolOwner) external payable {
        uint256 repaidAmount = msg.value;

        Pool storage pool = pools[_poolOwner];
        Loan storage loan = loans[_poolOwner][msg.sender];

        require(loan.status == LoanStatus.Borrowed, "Invalid loan to repay");
        
        uint256 requiredAmount = this.calculateRepayAmount(block.timestamp - loan.timestamp, loan.interestType, loan.interestStartRate, loan.interestCapRate, loan.amount);

        require(repaidAmount>= requiredAmount, "Not enough amount to repay the loan");

        // Resend rest of the Ether to borrower
        (bool sent,) = msg.sender.call{value: repaidAmount - requiredAmount}("");
        require(sent, "Failed to return Ether to msg.sender");

        uint256 netInterest = requiredAmount - loan.amount;
        uint256 platformFee = netInterest * adminSetting.platformFee / 100;
        uint256 ownerInterest = netInterest - platformFee;

        
        // Send platform Fee to vault address
        (bool sentToVault,) = msg.sender.call{value: platformFee}("");
        require(sentToVault, "Failed to return Ether to msg.sender");


        // Return NFT collateralized
        IERC721(loan.collection).safeTransferFrom(address(this), msg.sender, loan.tokenId);


        // Update pool
        if (pool.compound == true)
            pool.availableAmount += ownerInterest;
        else {
            (bool sentToPoolOnwer,) = msg.sender.call{value: ownerInterest}("");
            require(sentToPoolOnwer, "Failed to send Ether to sentToPoolOnwer");
        }

        pool.availableAmount += loan.amount;
        pool.totalInterest += ownerInterest;
        pool.updatedAt = block.timestamp;

        // Finalize loan
        loan.status = LoanStatus.Repaid;
    }

    /// @notice Liquidate the expired loan
    /// @dev Check if the grace period is expired
    /// @param _loan a parameter just like in doxygen (must be followed by parameter name)
    function liquidate (address _loan) external {
        Pool storage pool = pools[msg.sender];
        Loan storage loan = loans[msg.sender][_loan];

        require(loan.status == LoanStatus.Borrowed, "Invalid loan to liquidate");
        require(block.timestamp > loan.timestamp + loan.duration * 1 days + 1 days, "Not expired the grace date");

        // Take NFT item from escrow
        IERC721(loan.collection).safeTransferFrom(address(this), msg.sender, loan.tokenId);

        // Update pool
        pool.totalLiquidations += loan.amount;
        pool.updatedAt = block.timestamp;

        // Update loan
        loan.status = LoanStatus.Liquidated;

        emit LiquidatedLoan(pool.owner, loan.borrower, loan.amount);
    }
}