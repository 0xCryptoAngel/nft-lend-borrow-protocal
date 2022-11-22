// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IPikachu.sol";
import "./VerifySignature.sol";

contract Pikachu is IPikachu, VerifySignature, Ownable {

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
        uint256 _interestRate,
        uint256 _maxDuration,
        bool _compound,
        address[] memory _collections
    ) external payable {
        require(msg.value >= adminSetting.minDepositAmount, "createPool: Needs more coin to create pool");

        Pool storage newPool = pools[msg.sender];
        newPool.loanToValue = _loanToValue;
        newPool.maxAmount = _maxAmount;
        newPool.interestType = _interestType;
        newPool.interestRate = _interestRate;
        newPool.maxDuration = _maxDuration;
        newPool.compound = _compound;
        newPool.collections = _collections;

        newPool.owner = msg.sender;

        newPool.depositedAmount = msg.value;
        newPool.availableAmount  = msg.value;
        newPool.usableAmount  = msg.value;
        
        newPool.depositedAt = block.timestamp;
        newPool.createdAt = block.timestamp;
        newPool.updatedAt = block.timestamp;

        poolOwners[totalPools] = msg.sender;
        totalPools ++;
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

        uint256 _i = 0;
        bool validCollection = false;
        for (_i = 0; _i < pools[_poolOwner].collections.length; _i++)
            if (pools[_poolOwner].collections[_i] == _collection){
                validCollection = true;
                break;
            }
        require(validCollection, "Unacceptable NFT collection");

        IERC721(_collection).safeTransferFrom(msg.sender, address(this), _tokenId);
        
        (bool sent, bytes memory data) = msg.sender.call{value: _floorPrice}("");
        require(sent, "Failed to send Ether");


    }
}