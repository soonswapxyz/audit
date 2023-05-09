// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract  NFTWhitelist is AccessControl,Ownable{
    bytes32 public constant CHILD_LEVEL = keccak256("CHILD_LEVEL");
    mapping(address => bool) public list;

    constructor(address[] memory _nftList){
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(CHILD_LEVEL, _msgSender());
        _add(_nftList);
    }

    function addRole(address account) external onlyOwner{
        _grantRole(CHILD_LEVEL, account);
    }

     function delRole(address account) external onlyOwner{
        _grantRole(CHILD_LEVEL, account);
    }

    function addNFT(address[] memory _nftList) external onlyRole(CHILD_LEVEL) {
        _add(_nftList);
    }

    function _add(address[] memory _nftList) private {
        for(uint256 i=0;i<_nftList.length;i++){
            require(_nftList[i]!=address(0));
            list[_nftList[i]] = true;
        }
    }

    function delNFT(address[] memory _nftList) external onlyRole(CHILD_LEVEL){
        _del(_nftList);
    }

    function _del(address[] memory _nftList) private {
        for(uint256 i=0;i<_nftList.length;i++){
            require(_nftList[i]!=address(0));
            list[_nftList[i]] = false;
        }
    }
}
