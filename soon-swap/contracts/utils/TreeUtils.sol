// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {ISoonswapOrderCenter} from "../interfaces/ISoonswapOrderCenter.sol";


library TreeUtils {


    function getParent(uint256 index) public pure returns (uint256) {
        return (index - 1) / 2;
    }

    function getLeft(uint256 index) public pure returns (uint256) {
        return index * 2 + 1;
    }

    function getRight(uint256 index) public pure returns (uint256) {
        return index * 2 + 2;
    }


    function siftUpBuy(
        ISoonswapOrderCenter.OrderItem[] storage buyOrders,
        uint256 index
    ) internal {
     
        while (
            index > 0 &&
            (buyOrders[index].price > buyOrders[getParent(index)].price ||
                (buyOrders[index].price == buyOrders[getParent(index)].price &&
                    buyOrders[index].orderId <
                    buyOrders[getParent(index)].orderId))
        ) {
            swapDataBuy(buyOrders, getParent(index), index);
            index = getParent(index);
        }
    }

    function siftUpSell(
        ISoonswapOrderCenter.OrderItem[] storage sellOrders,
        uint256 index
    ) internal {
        while (
            index > 0 &&
            (sellOrders[index].price < sellOrders[getParent(index)].price ||
                (sellOrders[index].price ==
                    sellOrders[getParent(index)].price &&
                    sellOrders[index].orderId <
                    sellOrders[getParent(index)].orderId))
        ) {
            swapDataSell(sellOrders, getParent(index), index);
            index = getParent(index);
        }
    }


    function siftDownBuy(
        ISoonswapOrderCenter.OrderItem[] storage buyOrders,
        uint256 index
    ) internal {
        uint256 _index = index;
        uint256 left = getLeft(_index);
        uint256 right = getRight(_index);
        uint256 size = buyOrders.length;

        if (
            left < size &&
            (buyOrders[_index].price < buyOrders[left].price ||
                (buyOrders[_index].price == buyOrders[left].price &&
                    buyOrders[_index].orderId > buyOrders[left].orderId))
        ) {
            _index = left;
        }
       
        if (
            right < size &&
            (buyOrders[_index].price < buyOrders[right].price ||
                (buyOrders[_index].price == buyOrders[right].price &&
                    buyOrders[_index].orderId > buyOrders[right].orderId))
        ) {
            _index = right;
        }

        if (index != _index) {
            swapDataBuy(buyOrders, _index, index);
            siftDownBuy(buyOrders, _index);
        }
    }

    function siftDownSell(
        ISoonswapOrderCenter.OrderItem[] storage sellOrders,
        uint256 index
    ) internal {
        uint256 _index = index;
        uint256 left = getLeft(_index);
        uint256 right = getRight(_index);
        uint256 size = sellOrders.length;
        if (
            left < size &&
            (sellOrders[_index].price > sellOrders[left].price ||
                (sellOrders[_index].price == sellOrders[left].price &&
                    sellOrders[_index].orderId > sellOrders[left].orderId))
        ) {
            _index = left;
        }


        if (
            right < size &&
            (sellOrders[_index].price > sellOrders[right].price ||
                (sellOrders[_index].price == sellOrders[right].price &&
                    sellOrders[_index].orderId > sellOrders[right].orderId))
        ) {
            _index = right;
        }

        if (index != _index) {
            swapDataSell(sellOrders, _index, index);
            siftDownSell(sellOrders, _index);
        }
    }

    function swapDataSell(
        ISoonswapOrderCenter.OrderItem[] storage sellOrders,
        uint256 index1,
        uint256 index2
    ) internal {
        ISoonswapOrderCenter.OrderItem memory item = sellOrders[index1];
        sellOrders[index1] = sellOrders[index2];
        sellOrders[index2] = item;
    }

    function swapDataBuy(
        ISoonswapOrderCenter.OrderItem[] storage buyOrders,
        uint256 index1,
        uint256 index2
    ) internal {
        ISoonswapOrderCenter.OrderItem memory item = buyOrders[index1];
        buyOrders[index1] = buyOrders[index2];
        buyOrders[index2] = item;
    }

    function insertBuy(
        ISoonswapOrderCenter.OrderItem[] storage buyOrders,
        ISoonswapOrderCenter.OrderItem memory item
    ) internal {
        buyOrders.push(item);
        siftUpBuy(buyOrders, buyOrders.length - 1);
    }

    function insertSell(
        ISoonswapOrderCenter.OrderItem[] storage sellOrders,
        ISoonswapOrderCenter.OrderItem memory item
    ) internal {
        sellOrders.push(item);
        siftUpSell(sellOrders, sellOrders.length - 1);
    }


    function delBuyItem(
        ISoonswapOrderCenter.OrderItem[] storage buyOrders,
        uint256 index
    ) internal {

        if (buyOrders.length > 1) {
            buyOrders[index] = buyOrders[buyOrders.length - 1];
        }
        buyOrders.pop();
        siftDownBuy(buyOrders, index);
    }

    function delSellItem(
        ISoonswapOrderCenter.OrderItem[] storage sellOrders,
        uint256 index
    ) internal {
        if (sellOrders.length > 1) {
            sellOrders[index] = sellOrders[sellOrders.length - 1];
        }
        sellOrders.pop();
        siftDownSell(sellOrders, index);
    }
}
