// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import './interfaces/IFactory.sol';
import './SoonswapPair.sol';
import './interfaces/INFTWhiteList.sol';
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SoonswapFactory is IFactory,AccessControl,Ownable {
    bytes32 public constant CHILD_LEVEL = keccak256("CHILD_LEVEL");
    address public feeTo;
    address public NFTWhitelistAddr;

    mapping(address => bool) public isPair;
    mapping(address => mapping(address => address[])) public getPairs;
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

    constructor(address _feeTo, address _NFTWhitelistAddr)  {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CHILD_LEVEL, _msgSender());
        feeTo = _feeTo;
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
        require(tokenB == nftContract||tokenB==feeToken,'PARAM_CHECK_FAILED');
        require(checkNFT(nftContract),'Soonswap:nft not support');
        string memory _pairName  = pairName(feeToken,nftContract);
        pair = address(new SoonswapPair{salt : bytes32(keccak256(abi.encodePacked(tokenA, tokenB, block.timestamp)))}(_pairName));
        ISoonswapPair(pair).initialize(swapFee, nftContract, feeToken, feeTo);
        getPairs[tokenA][tokenB].push(pair);
        total+=1;
        isPair[pair] = true;
        emit PairCreated(tokenA, tokenB, swapFee, bilateral, nftContract, feeToken, pair, total);
    }

    function pairName(address _feeToken,address _nft) private view returns (string memory _pairName){
        string memory _tooken = "";
        if(_feeToken == address(0)){
            _tooken = "ETH";
        }else{
            _tooken = IERC20(_feeToken).symbol();
        }
        string memory _nftName = IERC20(_nft).symbol();
        return string(abi.encodePacked(_tooken, "-", _nftName));
    }

    function setFeeTo(address _feeTo) external onlyOwner{
        feeTo = _feeTo;
    }


    function getFeeTo() external view returns (address){
        return feeTo;
    }

    function checkNFT(address _pair) private view returns(bool) {
        return INFTWhiteList(NFTWhitelistAddr).list(_pair);
    }

    function setNFTWhitelistAddr(address addr) external onlyRole(CHILD_LEVEL){
        NFTWhitelistAddr = addr;
    }

}
