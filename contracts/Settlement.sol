// SPDX-License-Identifier: AGPL
pragma solidity ^0.8.17;

/*
................................................................................................................................... 
................................................................................................................................... 
...................................................................................................................................
..................................................................................... .............................................
..................................................................................      ........................................... 
................................................................................  :2BB: ........................................... 
..............................................................................  SQBBBBi ...........................................
............................................................................  XBPBBBB1ii7 .........................................
..................................         ................................ :BQOBiQBBrr27 .........................................
................................. QBBDq2Ui.   ...........................  XBlg . gBX:vs ..........................................
................................. .BBBBq1MQMXi   .......................  QB  ..  dB:rLL ..........................................
..................................  QBB7BBL7PQBP:  ....................  BQ  ... vB7i71 ...........................................
...................................  PBEBE.   :PBBj  .....         ...  BE ...  vBj:7ui ...........................................
....................................  sBP  ....  YBB5    .rj5SK5IJr.   Bd .... sBu:7jr ............................................
...................................... .gBI  ....  7BBLKMQEP2IU5XPZRMbQR .... 5BJ:7jr .............................................
.......................................  :RBq   ...  SBI.           .7bi  .. ZB7i7jr .....     ....................................
.........................................  :PBgj.        ............  ..s:7Bgir7ji ..   .uERB  ...................................
...........................................   2MBguS: ...................:QBu:7LJ:    :5RQEY:BL ...................................
..............................................  .jBB ................. .. iBrrv7   :SQQbi    BKvr .................................
................................................  B.  .................    Md::  UQQP:   ..  PBiu .................................
................................................ :B  ;PSB;......... ;PSB;  PM:UZQZr   ...... jQ7L .................................
................................................ .B  iE gj......... Bq BB  jBDDs   ......... iBY7 .................................
........................................   .     .B  ;BBB;....:v... ;BBB;  vB.       .......  QPi7 ................................
....................................... .DBQgqqL 2R:j7. . ... r5  .  ..  :rvB. .:r2XX. ...... PQi7 ................................
....................................... BB..rYIddB1IXdbi ..   jg:  ..  vSKSPQr.:ii..5B. ..    7BrY ................................
...................................... 1B        bZoooZP  .DBBBBBBB1. 7goooqB        SB   :LXPDQvvi ...............................
...................................... iBv .....  Qo.oi7 . PB.. ..BP ..Do.oQ5 .....  XMJqRRMPUvrv1v ...............................
....................................... iBI ..... :g.j: ... Pv...KI .. .J.D:  ....  XQZPXs7r77L7ri ................................
........................................ .QM  .... .ji...... PS.PK ....  iY. ....  RBviirLv7i .. ..................................
.........................................  DB2  ...  :i.....  .V. .....:i: ....  rBgiivsr .........................................
..........................................  iBBI   .. .......:...:............  PB1:7YY  ..........................................
............................................  7RBPiUu .......:i::..........  .2Bgri7J7  ...........................................
..............................................  :KRB. .:.................. :UZKBYivsi .............................................
................................................  gQ .:.................. :I7 .QEi7  ..............................................
................................................ 7B  ..................... X.5B1:Lv ...............................................
............................................  . :Br ...................... qBZr:vss ...............................................
........................................... iJ iQY ....................... 1Bg:vvi ................................................
.......................................... rB  B: ........................ .BZiv  .................................................
.......................................... sB   I ........................ .dD:Y ..................................................
.......................................... Bi   .J ........................ JBrv ..................................................
........................................... bB   .S ....................... :Bj7 ..................................................
............................................ Bq   .L ...................... :Rdi7 .................................................
.............................................. Bd  .: ...................... EgiY .................................................
.............................................. QBi gZ1Jr:  ................. Eg:j .................................................
............................................... 1BDBRPZRRQRRZP27.    ...... iBYrJ .................................................
................................................. irir7ir7sjSPMQBRbui  .:: UB2:71 .................................................
...................................................  iii       :iUPQQBR i QQ7i7u7 .................................................
..................................................... .........     .7Bv  Dg:7Yi ..................................................
....................................................................  sB   Bv7: ...................................................
...................................................................... PB  B5r. ...................................................
....................................................................... qBXB5r. ...................................................
........................................................................ igPYL. ...................................................
.......................................................................... VVJ  ...................................................
............................................................................  :....................................................
...................................................................................................................................
...................................................................................................................................
...................................................................................................................................
*/

import "solmate/src/tokens/WETH.sol";
import "./utils/BidSignatures.sol";
import "./utils/Pikapatible.sol";

/// @title PikaPool Protocol Settlement Contract
/// @author 0xViola and PikaPool Developers

/// @dev This contract lies at the heart of PikaPool's on-chain mechanics, providing batch settlement of mints
/// for 721A NFTs that extend the Pikapatible plugin. It need only ever be called by the PikaPool orchestrator,
/// which provides an array of bid signatures to mint NFTs to the winning bidders

contract Settlement is BidSignatures {

    /// @dev Struct of signature data for winning bids to be deconstructed and validated to mint NFTs
    /// @param bid The winning bid fed to this Settlement contract by the Orchestrator
    /// @param v ECDSA cryptographic recovery ID derived from digest hash and bidder privatekey
    /// @param r ECDSA cryptographic parameter derived from digest hash and bidder privatekey
    /// @param s ECDSA cryptographic parameter derived from digest hash and bidder privatekey
    struct Signature {
        Bid bid;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @dev WETH contract for this chain
    WETH public weth;

    /// @dev Maximum mint threshold amount to prevent excessive first-time token transfer costs
    /// @dev Stored in storage for gas optimization (as opposed to repeated mstores)
    uint256 public mintMax;

    /// @dev Mapping that stores keccak256 hashes of spent signatures to protect against replay attacks
    mapping (bytes32 => bool) public spentSigNonces;

    /// @dev Event emitted upon any signature's settlement failure, 
    /// used instead of reverts to ensure finality for successful mints even in the case of failures interspersed within the batch
    /// @param bidder The address of the winning bid's originator, in this case comparable to tx.origin
    /// @param reason The reason for the signature's failure. This can be one of several potential issues and is helpful for debugging.
    event SettlementFailure(address indexed bidder, bytes reason);

    constructor(address payable _wethAddress, uint256 _mintMax) {
        weth = WETH(_wethAddress);
        mintMax = _mintMax;
    }

    /// @dev Function to be called by the Orchestrator following the conclusion of each auction
    /// @dev To save gas, this function cycles through a series of checks via internal functions that simply trigger a continuation of the loop at the next index upon failure
    /// @param signatures Array of Signature structs to be deconstructed and verified before settling the auction
    /// @notice Once testing has been completed, this function will be restricted via access control to the Orchestrator only
    function finalizeAuction(Signature[] calldata signatures)
        external
    {
        // unchecked block provides a substantial amount of gas savings for larger collections, ie 10k pfps
        // it is impossible to overflow the only arithmetics inheriting the unchecked property: the for loop incrementor
        unchecked {
            Bid[] memory mints = new Bid[](signatures.length);
            for (uint256 i; i < signatures.length; ++i) {
                if (_aboveMintMax(
                    signatures[i].bid.amount, 
                    signatures[i].bid.bidder
                )) continue;
                if (_spentSig(
                    signatures[i].v,
                    signatures[i].r,
                    signatures[i].s,
                    signatures[i].bid.bidder
                )) continue;
                if (_verifySignature(
                    signatures[i].bid.auctionName,
                    payable(signatures[i].bid.auctionAddress),
                    signatures[i].bid.bidder,
                    signatures[i].bid.amount,
                    signatures[i].bid.basePrice,
                    signatures[i].bid.tip,
                    signatures[i].v,
                    signatures[i].r,
                    signatures[i].s
                )) {
                    spentSigNonces[
                        keccak256(
                            abi.encodePacked(
                                signatures[i].v,
                                signatures[i].r,
                                signatures[i].s
                            )
                        )
                    ] = true;
                    if(_settle(signatures[i].bid)) {
                        mints[i] = signatures[i].bid;
                    }
                } else {
                    emit SettlementFailure(
                        signatures[i].bid.bidder,
                        "Invalid Sig"
                    );
                }
            }
            uint256 balance = weth.balanceOf(address(this));
            weth.withdraw(balance);

            for (uint256 j; j < mints.length; ++j) {
                // ignore uninitialized slots; counter does not help in this case
                if (mints[j].auctionAddress == address(0x0)) continue;
                Pikapatible(payable(mints[j].auctionAddress)).mint{
                    value: mints[j].amount * mints[j].basePrice + mints[j].tip
                }(mints[j].bidder, mints[j].amount);
            }
        }
    }

    /// @dev Internal function to check against this Settlement contract's `mintMax` and reject excessive bid amounts
    /// @param _sigBidAmount The amount of NFTs requested by the bid
    /// @param _sigBidder The address of the winning bid's originator, in this case comparable to tx.origin
    function _aboveMintMax(uint256 _sigBidAmount, address _sigBidder) internal returns (bool excessAmt) {
        if (_sigBidAmount > mintMax) {
            emit SettlementFailure(
                _sigBidder,
                "Exceeds MintMax"
            );
            return true;
        }
    }
    
    /// @dev Internal function to check against storage mapping of keccak256 sig hashes for spent signatures
    /// @param _v ECDSA cryptographic recovery ID derived from digest hash and bidder privatekey
    /// @param _r ECDSA cryptographic parameter derived from digest hash and bidder privatekey
    /// @param _s ECDSA cryptographic parameter derived from digest hash and bidder privatekey
    /// @param _sigBidder The address of the winning bid's originator, in this case comparable to tx.origin
    function _spentSig(
        uint8 _v,
        bytes32 _r,
        bytes32 _s,
        address _sigBidder
    ) internal returns (bool sigSpent) {
        if (
            spentSigNonces[
                keccak256(
                    abi.encodePacked(
                        _v,
                        _r,
                        _s
                    )
                )
            ]
        ) {
            emit SettlementFailure(
                _sigBidder, 
                "Spent Sig"
            );
            return true;
        }
    }

    /// @dev Function to settle each winning bid via EIP-712 signature
    /// @param auctionName The name of the creator's NFT collection being auctioned
    /// @param auctionAddress The address of the creator NFT being bid on. Becomes a string off-chain.
    /// @param bidder The address of the winning bid's originator, in this case comparable to tx.origin.
    /// @param amount The number of assets being bid on.
    /// @param basePrice The base price per NFT set by the collection's creator
    /// @param tip The tip per NFT offered by the bidder in order to win a mint in the auction
    function _verifySignature(
        string memory auctionName,
        address auctionAddress,
        address bidder,
        uint256 amount,
        uint256 basePrice,
        uint256 tip,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (bool) {
        address recovered = ecrecover(
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    // gas optimization of BidSignatures.hashBid(): calldata < mstore/mload !
                    keccak256(
                        abi.encode(
                            BID_TYPE_HASH,
                            keccak256(bytes(auctionName)),
                            auctionAddress,
                            bidder,
                            amount,
                            basePrice,
                            tip
                        )
                    )
                )
            ),
            v,
            r,
            s
        );

        // handle signature error cases
        if (recovered == address(0) || recovered != bidder) return false;
        else return true;
    }

    /// @dev Internal function that finalizes the settlements upon verification of signatures
    /// @param _bid The bid on behalf of which payment is attempted
    function _settle(Bid memory _bid) internal returns (bool) {
        uint256 totalWETH = _bid.amount * _bid.basePrice + _bid.tip;
        try weth.transferFrom(_bid.bidder, address(this), totalWETH) returns (bool p) {
                return p;
        } catch {
            emit SettlementFailure(
                _bid.bidder,
                "Payment Failed"
            );
        }
    }

    receive() external payable {}
}
