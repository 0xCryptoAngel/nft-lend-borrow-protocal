// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract VerifySignature {
    function getMessageHash(
        address _collection,
        uint256 _floorPrice,
        uint256 _blockNumber
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_collection, _floorPrice, _blockNumber));
    }

    function getEthSignedMessageHash(bytes32 _messageHash)
        public
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
            );
    }
    function verify(
        address _signer,
        address _collection,
        uint256 _floorPrice,
        uint256 _blockNumber,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 messageHash = getMessageHash(_collection, _floorPrice, _blockNumber);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);

        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature)
        public
        pure
        returns (address)
    {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig)
        public
        pure
        returns (
            bytes32 r,
            bytes32 s,
            uint8 v
        )
    {
        require(sig.length == 65, "invalid signature length");

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }
}
