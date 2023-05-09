// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import './interfaces/IFactory.sol';
import './interfaces/INFTWhiteList.sol';
import './SoonPair.sol';

contract SoonFactory is IFactory, AccessControl, Ownable{
    bytes32 public constant CHILD_LEVEL = keccak256("CHILD_LEVEL");
    address public feeTo;
    address public orderCenter;
    address public NFTWhitelistAddr;

    mapping(address => bool) public isPair;
    mapping(address => mapping(address => address)) public getPair;
    uint256 public total;

    event PairCreated(
        address indexed token0,
        address indexed token1,
        uint8 swapFee,
        bool bilateral,
        address nftContract,
        address feeToken,
        address pair,
        uint allPairs);

    constructor(address _orderCenter,address _feeTo, address _NFTWhitelistAddr)  {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CHILD_LEVEL, _msgSender());
        feeTo = _feeTo;
        orderCenter = _orderCenter;
        NFTWhitelistAddr = _NFTWhitelistAddr;
    }



    function addRole(address account) external onlyOwner{
        _grantRole(CHILD_LEVEL, account);
    }

     function delRole(address account) external onlyOwner{
        _grantRole(CHILD_LEVEL, account);
    }

    function createPair(
        address tokenA,
        address tokenB,
        uint8 swapFee,
        bool bilateral,
        address nftContract,
        address feeToken
    ) external returns (address pair) {
        require(tokenA != tokenB, 'Soonswap: IDENTICAL_ADDRESSES');
        require(tokenA == nftContract||tokenA==feeToken,'PARAM_CHECK_FAILED');
        require(checkNFT(nftContract),'Soonswap:nft not support');
        if(getPair[tokenA][tokenB]== address(0)){
            pair =  address(new SoonPair{salt: bytes32(keccak256(abi.encodePacked(tokenA, tokenB,block.timestamp)))}());
            ISoonPair(pair).initialize(tokenA, swapFee, nftContract,orderCenter,feeToken,feeTo);
            getPair[tokenA][tokenB]=pair;
            total+=1;
            isPair[pair] = true;
            emit PairCreated(tokenA, tokenB, swapFee, bilateral, nftContract,feeToken, pair, total);
        }else{
            emit PairCreated(tokenA, tokenB, swapFee, bilateral, nftContract,feeToken, getPair[tokenA][tokenB], total);
        }
        
    }

    function setFeeTo(address _feeTo) external onlyOwner{
        feeTo = _feeTo;
    }

    function getFeeTo() external view returns (address ){
        return feeTo;
    }

    function checkNFT(address _pair) private view returns(bool) {
        return INFTWhiteList(NFTWhitelistAddr).list(_pair);
    }

    function setNFTWhitelistAddr(address addr) external onlyRole(CHILD_LEVEL){
        NFTWhitelistAddr = addr;
    }

}
