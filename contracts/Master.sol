// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IPikachu.sol";
import "./VerifySignature.sol";
contract Pikachu is IPikachu, VerifySignature, Ownable, IERC721Receiver {
    // uint256 constant BLOCK_PER_DAY = 7200;

    AdminSetting public adminSetting;
    
    mapping (uint256 => Pool) private pools;
    
    // totalPools:: total number of pools
    uint256 public totalPools;

    // loans:: poolIndex => borrower address
    mapping (uint256 => mapping (address => Loan)) public loans;

    modifier onlyCreator(uint256 poolId) {
        require(pools[poolId].owner == msg.sender, "onlyCreator: Invalid owner");
        _;
    }

    constructor (AdminSetting memory _adminSetting) {
        updateAdminSetting(_adminSetting);
    }

    /// @notice Update system settings
    function updateAdminSetting(AdminSetting memory _adminSetting) onlyOwner public {
        adminSetting = _adminSetting;
    }

    function verifiedCollections() view public returns(address[] memory){
        return adminSetting.verifiedCollections;
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
        Pool storage newPool = pools[totalPools];
        // require(newPool.status == PoolStatus.None, "createPool: Already exists");
        require(this.isListedCollection(_collections), "createPool: Unsupported collections provided");
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
        newPool.status = PoolStatus.Ready;

        emit CreatedPool(msg.sender, totalPools, newPool.depositedAmount);

        totalPools ++;
    }
    

    /// @notice set availabilty of pool (paused)
    function setPaused(
        uint256 _poolId,
        bool _paused
    ) external payable onlyCreator(_poolId){
        Pool storage pool = pools[_poolId];
        pool.paused = _paused;
    }

    /// @notice update a pool with provided information
    function updatePool(
        uint256 _poolId,
        uint256 _loanToValue,
        uint256 _maxAmount,
        InterestType _interestType,
        uint256 _interestStartRate,
        uint256 _interestCapRate,
        uint256 _maxDuration,
        bool _compound,
        address[] memory _collections
    ) external payable onlyCreator(_poolId){
        Pool storage pool = pools[_poolId];

        require(pool.status == PoolStatus.Ready, "updatePool: Invalid Pool to update");
        require(this.isListedCollection(_collections), "updatePool: Unsupported collections provided");

        pool.loanToValue = _loanToValue;
        pool.maxAmount = _maxAmount;
        pool.interestType = _interestType;
        pool.interestStartRate = _interestStartRate;
        pool.interestCapRate = _interestCapRate;
        pool.maxDuration = _maxDuration;
        pool.compound = _compound;
        pool.collections = _collections;
        pool.availableAmount += msg.value;
        pool.depositedAmount += msg.value;
        pool.updatedAt = block.timestamp;
    }

    function isListedCollection(address[] memory _collections) public view returns (bool isListed) {
        isListed = false;
        
        uint256 _i = 0;
        uint256 _j = 0;
        for (_i = 0; _i < _collections.length; _i++)
            for (_j = 0; _j < adminSetting.verifiedCollections.length; _j++) {
                if (_collections[_i] == adminSetting.verifiedCollections[_j]){
                    isListed = true;
                    break;
            }
            if (isListed == false)
                break;
            isListed = false;
        }
    }

    

    /// @notice Withdraw ETH from pool
    /// @param _amount eth value to withdraw from own pool
    function withdrawFromPool(uint256 _poolId, uint256 _amount) external onlyCreator(_poolId) {
        Pool storage pool = pools[_poolId];
        require(pool.status == PoolStatus.Ready, "withdrawFromPool: Invalid Pool");
        require(pool.availableAmount >= _amount, "withdrawFromPool: Withdrawal amount exceeds the balance");
        pool.availableAmount -= _amount;
        pool.updatedAt = block.timestamp;

        (bool sent,) = msg.sender.call{value: _amount}("");
        require(sent, "withdrawFromPool: Failed to send Ether");

        emit UpdatedPool(pool.owner, _poolId);
    }

    /// @notice Deposit ETH to pool
    function depositToPool(uint256 _poolId) external payable onlyCreator(_poolId) {
        Pool storage pool = pools[_poolId];

        require(pool.status == PoolStatus.Ready, "depositToPool: Invalid Pool");

        uint256 _amount = msg.value;
        pool.availableAmount += _amount;
        pool.updatedAt = block.timestamp;
        pool.depositedAmount += _amount;

        emit UpdatedPool(pool.owner, _poolId);
    }

    function getNumberByPoolsByOwner (address _owner) public view returns (uint256 count) {
        uint256 _i;
        for (_i = 0; _i < totalPools; _i++){
            if (pools[_i].owner == _owner)
                count ++;
        }
    }

    function getPoolsByOwner (address _owner) public view returns(Pool[] memory){
        Pool[] memory ownedPools = new Pool[](this.getNumberByPoolsByOwner(_owner));
        uint256 _i;
        uint256 _cnt = 0;
        for (_i = 0; _i < totalPools; _i++)
            if (pools[_i].owner == _owner) {
                ownedPools[_cnt] = pools[_i];
            }
        return ownedPools;
    }
    
    function getPoolById (uint256 _poolId) public view returns (Pool memory) {
        return pools[_poolId];
    }

    function borrow (uint256 _poolId, address _collection, uint256 _tokenId, uint256 _duration, uint256 _amount, bytes memory _signature, uint256 _floorPrice, uint256 _blockNumber) external {
        require(verify(owner(), _collection, _floorPrice, _blockNumber , _signature), "borrow: Invalid Signature");

        Pool storage pool = pools[_poolId];

        require(block.number - _blockNumber <= adminSetting.blockNumberSlippage, "borrow: Must have updated floor price!");
        require(_floorPrice * pool.loanToValue / 100 >= _amount, "borrow: Can't borrow more than LTV of the floor price");

        require(pool.status == PoolStatus.Ready, "borrow: The pool is not active at the moment");
        require(pool.paused == false, "borrow: The pool is paused by owner at the moment");
        require(pool.maxDuration >= _duration, "borrow: Request duration is longer than available duration");

        uint256 _i = 0;
        bool validCollection = false;
        for (_i = 0; _i < pool.collections.length; _i++)
            if (pool.collections[_i] == _collection){
                validCollection = true;
                break;
            }
        require(validCollection, "borrow: Unacceptable NFT collection");

        require(_floorPrice * pool.loanToValue / 100 >= _amount, "borrow: Request amount exceeds the Loan Value");
        require(pool.maxAmount >= _amount, "borrow: Request amount exceeds the max loanable amount");
        
        require(loans[_poolId][msg.sender].status != LoanStatus.Borrowed, "borrow: You have unpaid loan from this pool");
        
        IERC721(_collection).safeTransferFrom(msg.sender, address(this), _tokenId);

        (bool sent,) = msg.sender.call{value: _amount}("");
        require(sent, "borrow: Failed to send Ether");

        // create loan object
        
        Loan storage newLoan = loans[_poolId][msg.sender];

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

        pool.numberOfLoans ++;
        pool.numberOfOpenLoans ++;

        emit CreatedLoan(_poolId, newLoan.borrower, newLoan.amount);
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

    /// @notice Repay for a loan with Ether and update pool, loan
    /// @dev Explain to a developer any extra details
    /// @param _poolId Pool index msg.sender used
    function repay(uint256 _poolId) external payable {
        uint256 repaidAmount = msg.value;

        Pool storage pool = pools[_poolId];
        Loan storage loan = loans[_poolId][msg.sender];

        require(loan.status == LoanStatus.Borrowed, "repay: Invalid loan to repay");
        
        uint256 requiredAmount = this.calculateRepayAmount(block.timestamp - loan.timestamp, loan.interestType, loan.interestStartRate, loan.interestCapRate, loan.amount);

        require(repaidAmount>= requiredAmount, "repay: Not enough amount to repay the loan");

        if (repaidAmount - requiredAmount > 0) {
            // Resend rest of the Ether to borrower
            (bool sent,) = msg.sender.call{value: repaidAmount - requiredAmount}("");
            require(sent, "repay: Failed to return Ether to msg.sender");
        }

        uint256 netInterest = requiredAmount - loan.amount;
        uint256 platformFee = netInterest * adminSetting.platformFee / 10000;
        uint256 ownerInterest = netInterest - platformFee;

        // Send platform Fee to vault address
        (bool sentToVault,) = address(adminSetting.feeTo).call{value: platformFee}("");
        require(sentToVault, "repay: Failed to return Ether to Fee recipeint");

        // Return NFT collateralized
        IERC721(loan.collection).safeTransferFrom(address(this), msg.sender, loan.tokenId);

        // Update pool
        if (pool.compound == true)
            pool.availableAmount += ownerInterest;
        else {
            (bool sentToPoolOnwer,) = msg.sender.call{value: ownerInterest}("");
            require(sentToPoolOnwer, "repay: Failed to send Ether to sentToPoolOnwer");
        }

        pool.availableAmount += loan.amount;
        pool.totalInterest += ownerInterest;
        pool.updatedAt = block.timestamp;
        pool.numberOfOpenLoans --;

        // Finalize loan
        loan.status = LoanStatus.Repaid;
    }

    /// @notice Liquidate the expired loan
    /// @dev Check if the grace period is expired
    /// @param _loan a parameter just like in doxygen (must be followed by parameter name)
    function liquidate (uint256 _poolId, address _loan) external {
        Pool storage pool = pools[_poolId];
        Loan storage loan = loans[_poolId][_loan];

        require(loan.status == LoanStatus.Borrowed, "liquidate: Invalid loan to liquidate");
        require(block.timestamp > loan.timestamp + loan.duration + 1 days, "liquidate: Not expired the grace date");

        // Take NFT item from escrow
        IERC721(loan.collection).safeTransferFrom(address(this), msg.sender, loan.tokenId);

        // Update pool
        pool.totalLiquidations += loan.amount;
        pool.updatedAt = block.timestamp;
        pool.numberOfOpenLoans --;
        pool.numberOfLiquidations ++;

        // Update loan
        loan.status = LoanStatus.Liquidated;

        emit LiquidatedLoan(_poolId, loan.borrower, loan.amount);
    }
   function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}