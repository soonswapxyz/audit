// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ArrayUtils} from './utils/ArrayUtils.sol';
import {ISoonPair} from './interfaces/ISoonPair.sol';
import {IERC20} from  './interfaces/IERC20.sol';
import {IERC721} from  './interfaces/IERC721.sol';
import {IERC721Receiver} from  './interfaces/IERC721Receiver.sol';
import {TransferLib} from './libraries/TransferLib.sol';
import {ISoonswapOrderCenter} from  './interfaces/ISoonswapOrderCenter.sol';
contract SoonPair is ISoonPair, IERC721Receiver, ReentrancyGuard,Pausable {

    address public factory;
    address public orderCenter;
    address public token0;
    address public nftContract;
    address public feeToken;
    uint8   public swapFee;
    address public feeTo;

    modifier onlyCenter() {
        require(orderCenter == msg.sender, 'SoonPair: caller is not the orderCenter');
        _;
    }

    constructor(){
        factory = msg.sender;
    }

    function initialize(
        address _token0,
        uint8 _swapFee,
        address _nftContract,
        address _orderCenter,
        address _feeToken,
        address _feeTo
    ) external nonReentrant{
        require(msg.sender == factory, 'Soonswap: FORBIDDEN');
        token0 = _token0;
        swapFee = _swapFee;
        nftContract = _nftContract;
        feeToken = _feeToken;
        feeTo = _feeTo;
        orderCenter = _orderCenter;
    }

    function pause() external onlyCenter{
        _pause();
    }

    function unpause() external onlyCenter {
        _unpause();
    }

    function trading(Trading calldata _trading) payable external onlyCenter returns (bool){
        if (_trading.tradType == 1) {
            uint256 _price = _trading.txPrice * (1000 - swapFee) / 1000;
            require(_price > 0, 'Soonswap: _price > 0');
            uint256 _fee = _trading.txPrice - _price;

            if (feeToken != address(0)) {
                TransferLib.safeTransfer(feeToken, feeTo, _fee);
                TransferLib.safeTransfer(feeToken, _trading.to, _price);
                if (_trading.txPrice < _trading.orderPrice) {
                    TransferLib.safeTransfer(feeToken, _trading.from, _trading.orderPrice - _trading.txPrice);
                }
            } else {
                payable(feeTo).transfer(_fee);
                payable(_trading.to).transfer(_price);
                if (_trading.txPrice < _trading.orderPrice) {
                    payable(_trading.from).transfer(_trading.orderPrice - _trading.txPrice);
                }
            }
        } else if (_trading.tradType == 2) {
            IERC721(nftContract).safeTransferFrom(address(this),_trading.to, _trading.nftId);
        }
        emit tradingEvent(_trading.orderId, address(this), _trading.from, _trading.to, _trading.orderPrice, _trading.txPrice, _trading.nftId, _trading.tradType,_trading.fromType);
        return true;
    }

    function depositToToken(uint256[] calldata buyPrices) payable external nonReentrant whenNotPaused {
        require(token0 == feeToken, 'Soonswap: TOKEN0_NOT_IS_FEETOKEN');
        uint256 buyPricesSum;
        for(uint256 i=0;i<buyPrices.length;++i){
            require(buyPrices[i]>0,"price <= 0");
            buyPricesSum += buyPrices[i];
        }
        if (feeToken != address(0)) {
            IERC20(feeToken).transferFrom(msg.sender, address(this), buyPricesSum);
        } else {
            require(buyPricesSum <= msg.value, "Soonswap:Underpayment ETH0");
        }

        (uint256  orderId,uint256[] memory traded) = _depositToken(buyPrices);

        require(orderId>0, 'Soonswap: CREAT_BUY_ORDER_FAIL');         
        emit depositToTokenEvent(msg.sender, orderId, buyPricesSum, buyPrices,traded);

    }



    function _depositToken(uint256[] calldata buyPrices) private returns (uint256,uint256[] memory){
        ISoonswapOrderCenter.Order memory _buyOrder = ISoonswapOrderCenter.Order({
                            orderId : 0,
                            nftContract : nftContract,
                            feeToken : feeToken,
                            swapFee : swapFee,
                            pair : address(this),
                            user : msg.sender,
                            nfts:buyPrices,
                            prices : buyPrices

            });

        (uint256  orderId,uint256[] memory traded) =  ISoonswapOrderCenter(orderCenter).depositToken(_buyOrder);
        return (orderId,traded);
    }


    function depositToNFT(
        uint256[] calldata sellNfts,
        uint256[] calldata sellPrices
    ) external nonReentrant whenNotPaused{
        require(token0 == nftContract, 'Soonswap: TOKEN0_NOT_IS_NFTCONTRACT');
        require(sellNfts.length == sellPrices.length, 'Soonswap:length not equal');
        for (uint i = 0; i < sellNfts.length; i++) {
            require(sellPrices[i]>0,"price <= 0");
            IERC721(nftContract).transferFrom(msg.sender, address(this), sellNfts[i]);
        }
        (uint256 orderId,uint256[] memory traded) = _depositNft(sellPrices, sellNfts);
        require(orderId>0, 'Soonswap: CREAT_SELL_ORDER_FAIL');
        emit depositToNFTEvent(msg.sender, orderId, sellNfts, sellPrices,traded);
    }


    function _depositNft(uint256[] calldata sellPrices, uint256[] calldata sellNfts) private returns (uint256,uint256[] memory){
        ISoonswapOrderCenter.Order memory _sellOrder = ISoonswapOrderCenter.Order({
                                                orderId : 0,
                                                nftContract : nftContract,
                                                feeToken : feeToken,
                                                swapFee : swapFee,
                                                pair : address(this),
                                                user : msg.sender,
                                                nfts : sellNfts,
                                                prices : sellPrices
                                    });
        return ISoonswapOrderCenter(orderCenter).depositNft(_sellOrder);
    }

    function editToToken(Order[] calldata orders) payable external nonReentrant whenNotPaused{
        require(token0 == feeToken, 'Soonswap: TOKEN0_NOT_IS_FEETOKEN');
        uint256 _len = orders.length;
        uint256 newTotalPrices = 0;
        uint256 oldTotalPrices = ISoonswapOrderCenter(orderCenter).getBuyOrdersPrices(orders,nftContract,feeToken);
        for (uint256 j = 0; j < _len; ++j) {
            newTotalPrices+=ArrayUtils.arraySum(orders[j].prices);
        }
        if(newTotalPrices>oldTotalPrices){
            _transferFromToken(feeToken,msg.sender,address(this),newTotalPrices - oldTotalPrices);
  
        }
        if(oldTotalPrices>newTotalPrices){
            _transferFromToken(feeToken,address(this),msg.sender,oldTotalPrices-newTotalPrices);

        }

        for (uint256 j = 0; j < _len; ++j) {
            ISoonswapOrderCenter.Order memory _buyOrder = ISoonswapOrderCenter.Order({
                            orderId : orders[j].orderId,
                            nftContract : nftContract,
                            feeToken : feeToken,
                            swapFee : swapFee,
                            pair : address(this),
                            user : msg.sender,
                            nfts:orders[j].tokenIds,
                            prices : orders[j].prices
            });

            uint _buyPricesSum = ArrayUtils.arraySum(orders[j].prices);
            (uint256 editOrderId,uint256[] memory traded) = ISoonswapOrderCenter(orderCenter).editTokenOrder(_buyOrder);
            require(editOrderId>0, 'Soonswap: EDIT_TOKEN_FAIL');
            emit editToTokenEvent(msg.sender, editOrderId, _buyPricesSum, orders[j].prices,traded);
        }
    }

    function editToNFT(Order[] calldata orders) external nonReentrant whenNotPaused{
        require(token0 == nftContract, 'Soonswap: TOKEN0_NOT_IS_NFTCONTRACT');
        uint256 _len = orders.length;
        for (uint256 j = 0; j < _len; ++j) {
            ISoonswapOrderCenter.Order memory _sellOrder = ISoonswapOrderCenter.Order({
                            orderId : orders[j].orderId,
                            nftContract : nftContract,
                            feeToken : feeToken,
                            swapFee : swapFee,
                            pair : address(this),
                            user : msg.sender,
                            nfts:orders[j].tokenIds,
                            prices : orders[j].prices

            });
            (uint256 editOrderId,uint256[] memory traded) = ISoonswapOrderCenter(orderCenter).editNftOrder(_sellOrder);
            require(editOrderId>0, "Soonswap: EDIT_NFT_FAIL");
            emit editToNFTEvent(msg.sender, editOrderId, orders[j].tokenIds, orders[j].prices,traded);
        }


    }


    function exchange(Order[] calldata orders) payable external nonReentrant whenNotPaused{
        uint256 _len = orders.length;
        uint256 txType = orders[0].txType;

        if(txType==1){
            require(token0 == nftContract, 'Soonswap: TOKEN0_NOT_IS_NFTCONTRACT');
            uint256 orderTotalPrices = ISoonswapOrderCenter(orderCenter).getExchangeBuyPrices(orders,nftContract,feeToken);

            if (feeToken == address(0)) {
                require(orderTotalPrices <= msg.value, "Soonswap: Underpayment ETH0");
            }
        }
        if(txType==2){
            require(token0 == feeToken, 'Soonswap: TOKEN0_NOT_IS_FEETOKEN');
            uint256 orderTotalPrices = ISoonswapOrderCenter(orderCenter).getExchangeSellPrices(orders,nftContract,feeToken);
            uint256 hopePirces = 0;
            for (uint256 j = 0; j < _len; ++j) {
                hopePirces+=ArrayUtils.arraySum(orders[j].prices);
            }
            require(orderTotalPrices==hopePirces,"price error");
        }

        for (uint256 i = 0; i < _len; ++i) {
            require(orders[i].txType==txType,'txType error');
            if(orders[i].txType==1){
                bool result = _exchangeBuyOrder(orders[i].prices,orders[i].tokenIds,orders[i].orderId);
                require(result, "Soonswap: Exchange buy failed");
            }

            if(orders[i].txType==2){
                bool result = _exchangeSellOrder(orders[i].prices,orders[i].tokenIds,orders[i].orderId);
                require(result, "Soonswap: Exchange sell failed");
            }

        }
    }


    function _exchangeBuyOrder(uint256[] calldata prices, uint256[] calldata tokens,uint256 orderId) private returns (bool){
        require(prices.length==tokens.length,"length not equal");
        ISoonswapOrderCenter.Order memory order = ISoonswapOrderCenter.Order({
                                                orderId : orderId,
                                                nftContract : nftContract,
                                                feeToken : feeToken,
                                                swapFee : swapFee,
                                                pair : address(this),
                                                user : msg.sender,
                                                nfts : tokens,
                                                prices : prices
        });
        return ISoonswapOrderCenter(orderCenter).exchangeBuyOrder(order,feeTo);
    }


    function _exchangeSellOrder(uint256[] calldata prices, uint256[] calldata tokens,uint256 orderId) private returns (bool){
        require(prices.length==tokens.length,"length not equal");
        ISoonswapOrderCenter.Order memory order = ISoonswapOrderCenter.Order({
                                                orderId : orderId,
                                                nftContract : nftContract,
                                                feeToken : feeToken,
                                                swapFee : swapFee,
                                                pair : address(this),
                                                user : msg.sender,
                                                nfts : tokens,
                                                prices : prices
        });
        return ISoonswapOrderCenter(orderCenter).exchangeSellOrder(order);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function transferFromNFT(address nft, address from, address to, uint256 tokenId) external  onlyCenter returns (bool){
        IERC721(nft).safeTransferFrom(from, to, tokenId);
        return true;
    }

    function _transferFromToken(address token, address from, address to, uint256 amount)  private returns (bool){
        if (token != address(0)) {
            if(from != address(this)){
                IERC20(token).transferFrom(from, to, amount);
            }else{
                TransferLib.safeTransfer(token, to, amount);
            }
        } else {
            if(from == address(this)){
                (bool pay,) = payable(to).call{value : amount, gas : 20000}("");
                require(pay, 'Soonswap: Pay failure to pay ETH');
            }else{
                require(amount <= msg.value, "Soonswap: Underpayment ETH1");
            }
        }
        return true;
    }

    function transferFromToken(address token, address from, address to, uint256 amount) payable  public onlyCenter returns (bool){
        if (token != address(0)) {
            if(from != address(this)){
                IERC20(token).transferFrom(from, to, amount);
            }else{
                TransferLib.safeTransfer(token, to, amount);
            }
        } else {
            (bool pay,) = payable(to).call{value : amount, gas : 20000}("");
            require(pay, 'Soonswap: Pay failure to pay ETH');
        }
        return true;
    }

}
