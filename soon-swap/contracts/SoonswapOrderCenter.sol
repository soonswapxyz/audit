// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {TreeUtils} from './utils/TreeUtils.sol';
import {ISoonPair} from './interfaces/ISoonPair.sol';
import {IFactory} from './interfaces/IFactory.sol';
import {ISoonswapOrderCenter} from  './interfaces/ISoonswapOrderCenter.sol';

contract SoonswapOrderCenter is ISoonswapOrderCenter,AccessControl,Ownable{
    address public pairFactory;
    bytes32 public constant CHILD_LEVEL = keccak256("CHILD_LEVEL");
    // nft -> token
    mapping(address => mapping(address => uint256)) public nftBuyOrderId;
    mapping(address => mapping(address => uint256)) public nftSellOrderId;
    // nft -> token
    mapping(address => mapping(address => OrderItem[])) public buyOrderItems;
    mapping(address => mapping(address => OrderItem[])) public sellOrderItems;
    
    modifier onlyPair() {
        require(IFactory(pairFactory).isPair(msg.sender), 'SoonPair: caller is not the pair');
        _;
    }

    constructor()  {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CHILD_LEVEL, _msgSender());
    }

    function addRole(address account) external onlyOwner{
        _grantRole(CHILD_LEVEL, account);
    }

     function delRole(address account) external onlyOwner{
        _grantRole(CHILD_LEVEL, account);
    }

    function setPairFactory(address _pairFactory) external onlyRole(CHILD_LEVEL){
        pairFactory = _pairFactory;
    }


    function pausePair(address pair) external onlyRole(CHILD_LEVEL){
        ISoonPair(pair).pause();
    }

    function unpausePair(address pair) external onlyRole(CHILD_LEVEL){
        ISoonPair(pair).unpause();
    }

    function _getSellOrderId(
        address nftContract,
        address feeToken,
        uint256 orderId
    ) private returns (uint256){
        if (orderId > 0) {
            return orderId;
        } else {
            nftSellOrderId[nftContract][feeToken] += 1;
            return nftSellOrderId[nftContract][feeToken];
        }
    }

    function _getBuyOrderId(
        address nftContract,
        address feeToken,
        uint256 orderId
    ) private returns (uint256){
        if (orderId > 0) {
            return orderId;
        } else {
            nftBuyOrderId[nftContract][feeToken] += 1;
            return nftBuyOrderId[nftContract][feeToken];
        }
    }


    function getBuyOrdersPrices(
        ISoonPair.Order[] calldata orders,
        address nftContract,
        address feeToken
    ) external view returns(uint256){
        uint256 totalPrices = 0;
        OrderItem[] memory items = buyOrderItems[nftContract][feeToken];

        for(uint256 i=0;i<items.length;i++){
            for(uint256 j=0;j<orders.length;++j){
                if(items[i].orderId == orders[j].orderId){
                    totalPrices += items[i].price;
                }
            }
        }
       return totalPrices;
    }

    function getExchangeBuyPrices(
        ISoonPair.Order[] calldata orders,
        address nftContract,
        address feeToken
    ) external view returns(uint256){
        uint256 totalPrices = 0;
        OrderItem[] memory items = sellOrderItems[nftContract][feeToken];
        for(uint256 j=0;j<orders.length;j++){
            for(uint256 k=0;k<orders[j].tokenIds.length;k++){
                for(uint256 i=0;i<items.length;i++){
                    if(items[i].nftId == orders[j].tokenIds[k]){
                        totalPrices+=items[i].price;
                        break;
                    }
                }
            }

        }
       return totalPrices;
    }

    function getExchangeSellPrices(
        ISoonPair.Order[] calldata orders,
        address nftContract,
        address feeToken
    ) external view returns(uint256){
        uint256 totalPrices = 0;
        OrderItem[] memory items = buyOrderItems[nftContract][feeToken];
        
        for(uint256 j=0;j<orders.length;j++){
        
            uint256 orderId = orders[j].orderId;
            bool[] memory bools = new bool[]( orders[j].prices.length);
            for(uint256 k=0;k< orders[j].prices.length;k++){
                for(uint256 i=0;i<items.length;i++){
                    if(!bools[k]&& items[i].orderId == orderId &&items[i].price ==  orders[j].prices[k]){
                        totalPrices+=items[i].price;
                        bools[k]=true;
                        break;
                    }
                }
            }

        }
        
       return totalPrices;
    }

    function depositNft(
        Order calldata order
    ) external onlyPair returns (uint256,uint256[] memory){
        return _depositNft(order,2);
    }

    function _depositNft(
        Order calldata order,
        uint256 fromType
    ) private returns (uint256,uint256[] memory){
        uint256 curOrderId = _getSellOrderId(order.nftContract,order.feeToken,order.orderId);
        uint256[] memory traded = new uint256[](order.prices.length);
        for (uint i = 0; i < order.prices.length; i++) {
            if (order.prices[i] > 0) {
                if (buyOrderItems[order.nftContract][order.feeToken].length > 0 && order.prices[i] <= buyOrderItems[order.nftContract][order.feeToken][0].price) {
                    OrderItem memory item0 = buyOrderItems[order.nftContract][order.feeToken][0];                    
                    ISoonPair.Trading memory buyTrading = ISoonPair.Trading(
                        item0.orderId,
                        item0.user,
                        order.user,
                        item0.price,
                        order.prices[i],
                        order.nfts[i],
                        1,
                        fromType
                    );
                    
                    ISoonPair.Trading memory sellTrading = ISoonPair.Trading(
                            curOrderId,
                            order.user,
                            item0.user,
                            order.prices[i],
                            order.prices[i],
                            order.nfts[i],
                        2,
                        fromType
                    );
                    require(
                        ISoonPair(item0.pair).trading(buyTrading)
                        && ISoonPair(order.pair).trading(sellTrading),
                        'SoonswapOrderCenter: PAIR_TRADING_FAIL'
                    );
                    traded[i]=1;
                    TreeUtils.delBuyItem(buyOrderItems[order.nftContract][order.feeToken], 0);

                } else {
                    OrderItem memory item;
                    item.orderId = curOrderId;
                    item.price = order.prices[i];
                    item.pair = order.pair;
                    item.user = order.user;
                    item.nftId = order.nfts[i];

                    TreeUtils.insertSell(sellOrderItems[order.nftContract][order.feeToken], item);
                }
            }
        }
        return (curOrderId,traded);
    }

    function depositToken(
        Order calldata order
    ) external onlyPair returns (uint256,uint256[] memory){
        return _depositToken(order,1);
    }

    function _depositToken(
        Order calldata order,
        uint256 fromType
    ) private returns (uint256,uint256[] memory){
        uint256 curOrderId = _getBuyOrderId(order.nftContract,order.feeToken, order.orderId);
        uint256[] memory traded = new uint256[](order.prices.length);
        for (uint i = 0; i < order.prices.length; i++) {
            if (order.prices[i] > 0 ) {
                if (sellOrderItems[order.nftContract][order.feeToken].length>0 && order.prices[i] >= sellOrderItems[order.nftContract][order.feeToken][0].price) {
                    OrderItem memory item0 = sellOrderItems[order.nftContract][order.feeToken][0];
                    ISoonPair.Trading memory buyTrading = ISoonPair.Trading(
                        curOrderId,
                        order.user,
                        item0.user,
                        order.prices[i],
                        item0.price,
                        item0.nftId,
                        1,
                        fromType
                    );
                    ISoonPair.Trading memory sellTrading = ISoonPair.Trading(
                            item0.orderId,
                            item0.user,
                            order.user,
                            item0.price,
                            item0.price,
                            item0.nftId,
                        2,
                        fromType
                    );

                    require(
                        ISoonPair(order.pair).trading(buyTrading)
                        && ISoonPair(item0.pair).trading(sellTrading),
                        'SoonswapOrderCenter: PAIR_TRADING_FAIL'
                    );

                    traded[i] = 1;
                    TreeUtils.delSellItem(sellOrderItems[order.nftContract][order.feeToken], 0);
                } else {
                    OrderItem memory item;
                    item.orderId = curOrderId;
                    item.price = order.prices[i];
                    item.pair = order.pair;
                    item.user = order.user;
                    TreeUtils.insertBuy(buyOrderItems[order.nftContract][order.feeToken], item);
                }
            }
        }

        return (curOrderId,traded);
    }


    function editNftOrder(
        Order calldata order
    ) external onlyPair returns(uint256,uint256[] memory) {
        return _editNftOrder(order);
    }

    function _editNftOrder(
        Order calldata order
    ) private returns(uint256,uint256[] memory){
        require(order.nfts.length==order.prices.length,"length not equal");
        uint256 editOrderId = order.orderId;
        uint256 found=0;
        address user;
        address sellPair;
        for (uint i = 0; i < order.nfts.length; i++) {
            OrderItem[] memory _sellOrders = sellOrderItems[order.nftContract][order.feeToken];
            for (uint j = 0; j < _sellOrders.length; j++) {
                if (_sellOrders[j].orderId == editOrderId && _sellOrders[j].nftId == order.nfts[i]) {
                    found++;
                    if(user==address(0)){
                        user = _sellOrders[j].user;
                        sellPair = _sellOrders[j].pair;
                    }
                    TreeUtils.delSellItem(sellOrderItems[order.nftContract][order.feeToken], j);
                    break;
                }
            }
        }
        require(user==order.user,"user auth fail");
        require(found==order.nfts.length,"orderItem not found");
        for(uint256 i=0;i<order.nfts.length;i++){
            if(order.prices[i]==0){
                ISoonPair(sellPair).transferFromNFT(order.nftContract,sellPair,user,order.nfts[i]);
            }
        }
        return _depositNft(order,5);
    }


    function editTokenOrder(
        Order calldata order
    ) external onlyPair returns(uint256,uint256[] memory){
       return _editTokenOrder(order);
    }

    function _editTokenOrder(
        Order calldata order
    ) private returns(uint256,uint256[] memory){
        uint256 editOrderId = order.orderId;
        address user;
        uint256 found=0;
        for (uint i = 0; i < order.prices.length; i++) {
            OrderItem[] memory _buyOrders = buyOrderItems[order.nftContract][order.feeToken];
            for (uint j = 0; j < _buyOrders.length; j++) {
                if (_buyOrders[j].orderId == editOrderId) {
                    if(user==address(0)){
                        user = _buyOrders[j].user;
                    }
                    found++;
                    TreeUtils.delBuyItem(buyOrderItems[order.nftContract][order.feeToken], j);
                    break;
                }
            }
        }
        require(user==order.user,"user auth fail");
        require(found==order.prices.length,"orderItem not found");
        return _depositToken(order,4);
    }


    function exchangeBuyOrder(
        Order calldata order,address feeTo
    ) external onlyPair returns(bool){
       return _exchangeBuyOrder(order,feeTo);
    }

    function _exchangeBuyOrder(
        Order calldata order,address feeTo
    ) private returns(bool){
        uint256 editOrderId = order.orderId;
        address user;
        uint256 found=0;
        OrderItem[] memory items = new OrderItem[](order.nfts.length);
        for (uint i = 0; i < order.nfts.length; i++) {
            OrderItem[] memory _sellOrders = sellOrderItems[order.nftContract][order.feeToken];
            for (uint j = 0; j < _sellOrders.length; j++) {
                if (_sellOrders[j].orderId == editOrderId && _sellOrders[j].nftId == order.nfts[i]) {
                    if(user==address(0)){
                        user = _sellOrders[j].user;
                    }
                    items[found] = _sellOrders[j];
                    found++;
                    TreeUtils.delSellItem(sellOrderItems[order.nftContract][order.feeToken], j);
                    break;
                }
            }
        }

    require(found==order.nfts.length,"orderItem not found");
        uint256 sellPricesSum = 0;
        for(uint256 i=0;i<items.length;i++){
            sellPricesSum+=items[i].price;
            ISoonPair.Trading memory sellTrading = ISoonPair.Trading(
                items[i].orderId, 
                items[i].user,
                order.user,
                items[i].price,
                items[i].price,
                items[i].nftId,
                2,
                3

            );
            require(
                 ISoonPair(order.pair).trading(sellTrading),
                'SoonswapOrderCenter: PAIR_TRADING_FAIL'
            );
            
        }

        uint256 _amount = sellPricesSum * (1000 - order.swapFee) / 1000;
        uint256 _fee = sellPricesSum * order.swapFee / 1000;
        ISoonPair(order.pair).transferFromToken(order.feeToken, order.user, user, _amount);
        ISoonPair(order.pair).transferFromToken(order.feeToken,order.user,feeTo,_fee);
        return true;
    }

    function exchangeSellOrder(
        Order calldata order
    ) external onlyPair returns(bool){
       return _exchangeSellOrder(order);
    }

    function _exchangeSellOrder(
        Order calldata order
    ) internal returns(bool){
        uint256[] calldata nfts = order.nfts;
        uint256 editOrderId = order.orderId;
        uint256 found=0;
        OrderItem[] memory items = new OrderItem[](order.prices.length);
        for (uint i = 0; i < order.prices.length; i++) {
            OrderItem[] memory _buyOrders = buyOrderItems[order.nftContract][order.feeToken];
            for (uint j = 0; j < _buyOrders.length; j++) {
                if (_buyOrders[j].orderId == editOrderId && _buyOrders[j].price == order.prices[i]) {
                    items[found] = _buyOrders[j];
                    found++;
                    TreeUtils.delBuyItem(buyOrderItems[order.nftContract][order.feeToken], j);
                    break;
                }
            }
        }
        require(found==nfts.length,"orderItem not found");
        for(uint256 i=0;i<items.length;i++){
            ISoonPair.Trading memory buyTrading = ISoonPair.Trading(
                items[i].orderId,
                items[i].user,
                order.user,
                items[i].price,
                order.prices[i],
                nfts[i],
                1,
                3
            );
            require(
                        ISoonPair(order.pair).trading(buyTrading),
                        'SoonswapOrderCenter: PAIR_TRADING_FAIL'
                    );
            ISoonPair(order.pair).transferFromNFT(order.nftContract, order.user, items[i].user, nfts[i]);
            
        }
        return true;
    }  
}
