// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.17;

/// @title PikaPool Protocol Settlement Contract
/// @author 0xViola, 0xArceus, and PikaPool Developers

/// @dev This contract is abstract and inherited by the Settlement contract, 
/// providing the Bid struct type as well as the EIP712 hashing logic and variables to create the domain separator

abstract contract BidSignatures {

    /// @dev Struct of bid data to be hashed and signed for meta-transactions.
    /// @param auctionName The name of the creator's NFT collection being auctioned
    /// @param auctionAddress The address of the creator NFT being bid on. Becomes a string off-chain.
    /// @param bidder The address of the bid's originator, similar to tx.origin.
    /// @param amount The number of assets being bid on.
    /// @param basePrice The base price per NFT set by the collection's creator
    /// @param tip The tip per NFT offered by the bidder in order to win a mint in the auction
    struct Bid {
        string auctionName;
        address auctionAddress;
        address bidder;
        uint256 amount;
        uint256 basePrice;
        uint256 tip;
    }

    /// @dev The EIP-712 type hash of the bid struct, required to derive domain separator
    bytes32 internal constant BID_TYPE_HASH =
        keccak256(
            "Bid(string auctionName,address auctionAddress,address bidder,uint256 amount,uint256 basePrice,uint256 tip)"
        );

    /// @dev The EIP-712 domain type hash, required to derive domain separator
    bytes32 internal constant DOMAIN_TYPE_HASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    /// @dev The EIP-712 domain name, required to derive domain separator
    bytes32 internal constant DOMAIN_NAME = keccak256("Pikapool Auction");

    /// @dev The EIP-712 domain version, required to derive domain separator
    bytes32 internal constant DOMAIN_VERSION = keccak256("1");

    /// @dev The EIP-712 domain separator, computed in the constructor using the current chain id and settlement
    /// contract's own address to prevent replay attacks across networks
    bytes32 public immutable DOMAIN_SEPARATOR = 
        keccak256(
            abi.encode(
            DOMAIN_TYPE_HASH,
            DOMAIN_NAME,
            DOMAIN_VERSION,
            block.chainid,
            address(this)
        )
        );

    /// @dev Function to compute hash of a PikaPool bid
    /// @param bid The Bid struct to be hashed
    function hashBid(Bid memory bid) public pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    BID_TYPE_HASH,
                    keccak256(bytes(bid.auctionName)),
                    bid.auctionAddress,
                    bid.bidder,
                    bid.amount,
                    bid.basePrice,
                    bid.tip
                )
            );
    }

    /// @dev Function to compute hash of fully EIP-712 encoded message for the domain to be used with ecrecover()
    /// @param bid The Bid struct to be hashed using hashBid and then hashed again in keeping with EIP712 standards
    function hashTypedData(Bid memory bid) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, hashBid(bid))
            );
    }
}
