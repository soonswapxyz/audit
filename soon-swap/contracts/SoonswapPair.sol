// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {ArrayUtils} from './utils/ArrayUtils.sol';
import {ISoonswapPair} from './interfaces/ISoonswapPair.sol';
import {SoonswapERC20} from './SoonswapERC20.sol';
import {IERC20} from  './interfaces/IERC20.sol';
import {IERC721} from  './interfaces/IERC721.sol';
import {IERC721Receiver} from  './interfaces/IERC721Receiver.sol';
import {TransferLib} from './libraries/TransferLib.sol';
import {IFactory} from './interfaces/IFactory.sol';

contract SoonswapPair is ISoonswapPair, IERC721Receiver, SoonswapERC20,ReentrancyGuard {

    address public factory;
    address public nftContract;
    address public feeToken;
    uint8   public swapFee;
    address public feeTo;
    uint256 private reserve0;
    uint256 private reserve1;

    constructor(string memory _pairName) SoonswapERC20(_pairName, _pairName){
        factory = msg.sender;
    }

    function getReserves() public view returns (uint256 _reserve0, uint256 _reserve1) {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    function getSellPrice() public view returns (uint256) {
        if (reserve1 < 1) {
            return 0;
        }
        return ((1000 - swapFee) * reserve0) / (reserve1 * 1000 + 1000);
    }

    function getBuyPrice() public view returns (uint256) {
        if (reserve1 < 2) {
            return 0;
        }
        return ((1000 + swapFee) * reserve0) / (reserve1 * 1000 - 1000);
    }

    function getSellPrices(uint256 _number) public view returns (uint256) {
        if (reserve1 < 1) {
            return 0;
        }
        return ((1000 - swapFee) * reserve0 * _number) / ((reserve1 + _number) * 1000);
    }

    function getBuyPrices(uint256 _number) public view returns (uint256) {
        if (reserve1 < 2) {
            return 0;
        }
        return ((1000 + swapFee) * reserve0 * _number) / ((reserve1 - _number) * 1000);
    }

    // 初始化pair合约属性, 仅在第一次由工厂合约部署时调用
    function initialize(
        uint8 _swapFee,
        address _nftContract,
        address _feeToken,
        address _feeTo
    ) external nonReentrant {
        require(msg.sender == factory, 'Soonswap: FORBIDDEN');
        swapFee = _swapFee;
        nftContract = _nftContract;
        feeToken = _feeToken;
        feeTo = _feeTo;
    }
    function addLiquidity(
        uint256[] calldata _tokenIds,
        uint256 _tokenAmount
    ) payable external nonReentrant returns (uint256 liquidity){

        uint256 _nftCount = _tokenIds.length;
        require((_nftCount * reserve0) <= (reserve1 * _tokenAmount), 'Soonswap: NFT<->TOKEN_RATIO_ERROR');
        for (uint i = 0; i < _nftCount; i++) {
            IERC721(nftContract).safeTransferFrom(msg.sender, address(this), _tokenIds[i]);
        }
        if (feeToken != address(0)) {
            IERC20(feeToken).transferFrom(msg.sender, address(this), _tokenAmount);
        } else {
            require(_tokenAmount == msg.value, 'Soonswap: _tokenAmount == msg.value');
        }

        uint256 _totalSupply = totalSupply();
        uint256 _liquidity = 0;
        if (_totalSupply > 0) {
            _liquidity = (_nftCount * _totalSupply) / reserve1;
            if ((_nftCount * _totalSupply) % reserve1 > 0) {
                _liquidity += 1;
            }
        } else {
            _liquidity = 10 ** 18;
        }
        require(_liquidity > 0, 'Soonswap: _liquidity > 0');
        _mint(msg.sender, _liquidity);
        _update();
        emit addLiquidityEvent(msg.sender, _tokenIds, _tokenAmount, _liquidity);
        return _liquidity;
    }

    function removeLiquidity(uint256 lpAmount,uint256[] memory _nfts) payable external nonReentrant returns (uint256 _nftAmount, uint256 _tokenAmount){
        uint256 _totalSupply = totalSupply();
        _tokenAmount = reserve0 * lpAmount / _totalSupply;
        _nftAmount = reserve1 * lpAmount / _totalSupply;
        require(_nftAmount == _nfts.length, 'Soonswap: The NFT number check failed');
        require(_tokenAmount > 0, 'Soonswap: _tokenAmount > 0');
        if (feeToken != address(0)) {
            TransferLib.safeTransfer(feeToken, msg.sender, _tokenAmount);
        } else {
            (bool success,) = payable(msg.sender).call{value : _tokenAmount}("");
            require(success, 'Soonswap: Failure to pay ETH');
        }

        if (_nftAmount > 0) {
            for (uint i = 0; i < _nfts.length; i++) {
                IERC721(nftContract).safeTransferFrom(address(this), msg.sender, _nfts[i]);
            }
        }
        _burn(msg.sender, lpAmount);
        _update();
        emit removeLiquidityEvent(msg.sender, _nfts, _tokenAmount, lpAmount);
    }

    function _update() private {
        if (feeToken != address(0)) {
            reserve0 = uint256(IERC20(feeToken).balanceOf(address(this)));
        } else {
            reserve0 = address(address(this)).balance;
        }
        reserve1 = uint256(IERC721(nftContract).balanceOf(address(this)));
    }


    function swap(uint256[] memory _tokenAmounts, uint256[] memory _tokenIds, uint256 txType) payable external nonReentrant{
        require(_tokenAmounts.length==_tokenIds.length,"length not equal");
        uint256 _price = 0;
        address _feeTo = IFactory(factory).getFeeTo();
        uint256 pricesSum = ArrayUtils.arraySum(_tokenAmounts);
        if (_tokenAmounts.length > 0 && txType == 1) {
            _price = getBuyPrices(_tokenAmounts.length);
            uint256 _feeAmount = _price * swapFee / (1000 + swapFee) * 20 / 100;
            if (feeToken != address(0)) {
                require(_verifySlippage(_price, pricesSum, txType), 'Soonswap: High slippage');
                IERC20(feeToken).transferFrom(msg.sender, address(this), _price - _feeAmount);
                IERC20(feeToken).transferFrom(msg.sender, _feeTo, _feeAmount);
            } else {
                require(_verifySlippage(_price, msg.value, txType), 'Soonswap: High slippage');
                require(pricesSum <= msg.value, 'Soonswap: money <= msg.value');
                (bool success,) = payable(_feeTo).call{value : _feeAmount}("");
                require(success, 'Soonswap: Failure to pay ETH');
                if (_price < (msg.value - 50) ) {
                    (bool refund,) = payable(msg.sender).call{value : msg.value - _price}("");
                    require(refund, 'Soonswap: Refund to pay ETH');
                }
            }

            for (uint i = 0; i < _tokenAmounts.length; i++) {
                require(_tokenAmounts[i] > 0, 'SoonswapPair: _tokenAmounts > 0');
                uint256 _tokenIdOne = _tokenIds[i];
                IERC721(nftContract).safeTransferFrom(address(this), msg.sender, _tokenIdOne);
                uint256 _txPirce = 0;
                if(i > 0){
                    _txPirce =  getBuyPrices(i+1) - getBuyPrices(i);
                }else{
                    _txPirce =  getBuyPrices(i+1);
                }
                emit Swap(msg.sender, _price, _tokenIdOne, _txPirce, _tokenIdOne, txType);
            }
        } else if (_tokenIds.length > 0 &&  txType == 2) {
            _price = getSellPrices(_tokenIds.length);
            uint256 _sellAmount = _price;
            uint256 _feeAmount = _price * 1000 / (1000 - swapFee) * swapFee * 20 / 100000;
            require(_verifySlippage(_sellAmount, pricesSum, txType), 'Soonswap: High slippage');
            if (feeToken != address(0)) {
                TransferLib.safeTransfer(feeToken, msg.sender, _sellAmount);
                TransferLib.safeTransfer(feeToken, _feeTo, _feeAmount);
            } else {
                (bool success,) = payable(msg.sender).call{value : _sellAmount}("");
                require(success, 'Soonswap: Failure to pay ETH');
                (bool feeSuccess,) = payable(_feeTo).call{value : _feeAmount}("");
                require(feeSuccess, 'Soonswap: Fee failure to pay ETH');
            }
            for (uint i = 0; i < _tokenIds.length; i++) {
                require(_price > 0, 'SoonswapPair.swap: _price > 0');
                IERC721(nftContract).safeTransferFrom(msg.sender, address(this), _tokenIds[i]);
                uint256 _txPirce = 0;
                if(i > 0){
                    _txPirce =  getSellPrices(i+1) - getSellPrices(i);
                }else{
                    _txPirce =  getSellPrices(i+1);
                }
                emit Swap(msg.sender, _price, _tokenIds[i], _txPirce, _tokenIds[i], txType);
            }
        }
        _update();
    }

    function _verifySlippage(uint256 amount, uint256 pricesSum, uint256 txType) private pure returns (bool){
        if (txType == 1) {
            if (amount <= pricesSum) {
                return true;
            } else {
                return false;
            }
        }
        if (txType == 2) {
            if (amount >= pricesSum) {
                return true;
            } else {
                return false;
            }
        }
        return false;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
