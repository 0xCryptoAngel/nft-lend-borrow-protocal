// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
interface IPikachu {


    /// 
    struct AdminSetting {
        /// verifiedCollections:: array of ERC721 addresses to be accepted
        address[] verifiedCollections;
        /// feeTo:: address of fee receiptant
        address feeTo;
        /// minDepositAmount:: minimal amount of creating pool
        uint256 minDepositAmount;
        /// platformFee:: platform fee to apply for interest in basis point
        uint32 platformFee;
        /// blockNumberSlippage:: allowing block number slippage, 300 by default
        uint32 blockNumberSlippage;
    }

    // Enum representing Pool status
    enum PoolType {
        Changeable,
        Inchangeable
    }

    // Enum representing Pool status
    enum PoolStatus {
        None,
        Ready,
        Disabled
    }
    // Enum representing interest type
    enum InterestType  {
        Linear,
        Curved
    }

    // pools:: array of pools
    struct Pool {
        // owner:: Pool creator
        address owner;
        // status:: Pool status
        PoolStatus status;
        // depositedAmount:: Accumulated deposited amount
        uint256 depositedAmount;
        // borrowedAmount:: Total borrowed amount
        uint256 borrowedAmount;
        // availableAmount:: Available amount
        uint256 availableAmount;
        // nftLocked:: Number of locked NFTs
        uint256 nftLocked;
        // totalLiquidations:: Accumulated amount of liquidations
        uint256 totalLiquidations;
        // totalLoans:: Accumulated amount of loans
        uint256 totalLoans;
        // totalInterest:: Accumulated amount of interest
        uint256 totalInterest;
        // depositedAt:: Deposited timestamp
        uint256 depositedAt;
        // createdAt:: Created timestamp
        uint256 createdAt;
        // updatedAt:: Updated timestamp
        uint256 updatedAt;
        // lastLoanAt:: Last loan timestamp
        uint256 lastLoanAt;
        

        // Properties used to create a pool

        // loanToValue:: Loan to value of the NFT you want to give, in percentage, ex: 30
        uint256 loanToValue;
        // maxAmount:: May amount per loan you want to do, default should be pool size
        uint256 maxAmount;
        // interestType:: Dynamic will use our own model, if set to manual, you have to provide fees per day to pay
        InterestType interestType;
        // interestStartRate:: If interestType set to manual, provide interest rate per day, in basis point
        uint256 interestStartRate;
        // interestCapRate:: This would be the second parameter of the rate calculation
        uint256 interestCapRate;
        // maxDuration:: max duration of a loan
        uint256 maxDuration;
        // compound:: if set to true, reinvest profit in pool, otherwise they are sent to your wallet
        bool compound;
        address[] collections;
    }

    // Enum representing loan status
    enum LoanStatus  {
        None,
        Borrowed,
        Repaid,
        Liquidated
    }

    // loads: array of loads
    struct Loan {
        // borrower:: borrower, loan creator
        address borrower;
        // amount:: amount of loan
        uint256 amount;
        // duration:: loan duration in day
        uint256 duration;
        // collection:: NFT collection address used for collateral
        address collection;
        // tokenId:: NFT token Id used for collateral
        uint256 tokenId;
        // status:: loan status
        LoanStatus status;
        // blockNumber:: block number at loan timestamp
        uint256 blockNumber;
        // timestamp:: loan created timestamp
        uint256 timestamp;

        // interestType:: Dynamic will use our own model, if set to manual, you have to provide fees per day to pay
        InterestType interestType;
        // interestStartRate:: If interestType set to manual, provide interest rate per day, in basis point
        uint256 interestStartRate;
        // interestCapRate:: This would be the second parameter of the rate calculation
        uint256 interestCapRate;
    }
    
    /// @notice pool creation event
    event CreatedPool(address indexed poolOwner, uint256 indexed poolId, uint256 amount);

    /// @notice loan creation event
    event CreatedLoan(uint256 indexed poolId, address indexed borrower, uint256 amount);

    /// @notice pool update event
    event UpdatedPool(address indexed poolOwner, uint256 indexed poolId);

    /// @notice liquidate loan
    event LiquidatedLoan(uint256 indexed poolId, address indexed borrower, uint256 amount);

    function borrow (uint256 _poolId, address _collection, uint256 _tokenId, uint256 _duration, uint256 _amount, bytes memory _signature, uint256 _floorPrice, uint256 _blockNumber) external;
    function repay(uint256 _poolId) external payable;
}