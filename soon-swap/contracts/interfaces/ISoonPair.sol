// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


interface ISoonPair {

    event depositToTokenEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256 buyPricesSum,
        uint256[] buyPrices,
        uint256[] traded
    );

    event editToTokenEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256 buyPricesSum,
        uint256[] buyPrices,
        uint256[] traded
    );

    event depositToNFTEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256[] nfts,
        uint256[] sellPrices,
        uint256[] traded
    );

    event editToNFTEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256[] nfts,
        uint256[] sellPrices,
        uint256[] traded
    );

    event tradingEvent(
        uint256 orderId,
        address pair,
        address from,
        address to,
        uint256 orderPrice,
        uint256 txPrice,
        uint256 tokenId,
        uint txType,
        uint fromType
    );

    event Sync(uint256 reserve0, uint256 reserve1);

    struct Trading {
        uint256 orderId;
        address from;
        address to;
        uint256 orderPrice;
        uint256 txPrice;
        uint256 nftId;
        uint tradType;
        uint fromType;
    }

    // struct Order {
    //     uint256 orderId;
    //     uint256[]  prices;
    //     uint256[]  tokenIds;
    //     uint256 txType;
    // }

    struct Order {
        uint256 orderId;
        uint256[] prices;
        uint256[] tokenIds;
        uint256 txType;
    }

    function initialize(
        address _token0,
        uint8 _swapFee,
        address _nftContract,
        address _orderCenter,
        address _feeToken,
        address _feeTo
    ) external;

    function trading(Trading memory trading) payable external returns (bool);

    function transferFromNFT(address nft, address from, address to, uint256 tokenId) external  returns (bool);

    function transferFromToken(address token, address from, address to, uint256 amount) payable  external returns (bool);

    function pause() external;

    function unpause() external;

}
