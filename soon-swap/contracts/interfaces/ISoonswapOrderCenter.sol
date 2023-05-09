// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {ISoonPair} from "./ISoonPair.sol";

interface ISoonswapOrderCenter {
    struct Order {
        uint256 orderId;
        address nftContract;
        address feeToken;
        uint8 swapFee;
        address pair;
        address user;
        uint256[] nfts;
        uint256[] prices;
    }

    struct OrderItem {
        uint256 orderId;
        uint256 price;
        uint256 nftId;
        address pair;
        address user;
    }

    function getBuyOrdersPrices(
        ISoonPair.Order[] calldata orders,
        address nftContract,
        address feeToken
    ) external view returns (uint256);

    function getExchangeBuyPrices(
        ISoonPair.Order[] calldata orders,
        address nftContract,
        address feeToken
    ) external view returns (uint256);

    function getExchangeSellPrices(
        ISoonPair.Order[] calldata orders,
        address nftContract,
        address feeToken
    ) external view returns (uint256);

    function depositNft(
        Order calldata order
    ) external returns (uint256, uint256[] memory);

    function depositToken(
        Order calldata order
    ) external returns (uint256, uint256[] memory);

    function editNftOrder(
        Order calldata order
    ) external returns (uint256, uint256[] memory);

    function editTokenOrder(
        Order calldata order
    ) external returns (uint256, uint256[] memory);

    function exchangeBuyOrder(
        Order calldata order,
        address feeTo
    ) external returns (bool);

    function exchangeSellOrder(Order calldata order) external returns (bool);
}
