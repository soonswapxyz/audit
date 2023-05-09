// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


import "./interfaces/ISoonFarming.sol";
import {TransferLib} from './libraries/TransferLib.sol';

import "./SoonFarming.sol";
import "./Allowlisted.sol";

contract FarmFsctory is Allowlisted, AccessControl, Pausable,Ownable {
    bytes32 public constant CHILD_LEVEL = keccak256("CHILD_LEVEL");

    mapping(address => address[]) public getFarm;
    address[] public allFarm;

    event createFarmEvent(
        address farm,
        string name,
        address stakeTokenAddr,
        uint rewardTokenNumber,
        address[] _rewardTokens,
        uint256[] _rewards,
        uint256 beginTime,
        uint256 endTime
    );

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



    function pause() public onlyRole(CHILD_LEVEL) {
        _pause();
    }

    function unpause() public onlyRole(CHILD_LEVEL) {
        _unpause();
    }

    function blockAccount(address[] memory accounts) external onlyRole(CHILD_LEVEL) {
        for (uint i = 0; i < accounts.length; i++) {
            _blockAddress(accounts[i]);
        }
    }

    function unblockAccount(address[] memory accounts) external onlyRole(CHILD_LEVEL) {
        for (uint i = 0; i < accounts.length; i++) {
            _unblockAddress(accounts[i]);
        }
    }

    function isAccountBlocked(address account) external view returns (bool){
        return IsAccountBlocked(account);
    }

    function allFarmLength() external view returns (uint) {
        return allFarm.length;
    }



    function getFarms(address lpToken) external view returns (address[] memory farms){
        return getFarm[lpToken];
    }

    function createFarm(
        string memory _name,
        address _stakeTokenAddr,
        uint _rewardTokenNumber,
        address[] memory _rewardTokens,
        uint256[] memory _rewards,
        uint256 _beginTime,
        uint256 _endTime
    ) external onlyRole(CHILD_LEVEL) returns (address farm) {
        //require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "SoonswapFactory:Only administrators have create Farm privileges");
        require(!paused(), "SoonswapFactory: createFarm suspended due to paused");
        uint timestamp = block.timestamp;
        uint _rewardsDuration = _endTime - _beginTime;
        bytes32 _salt = keccak256(abi.encodePacked(_name, _beginTime, _endTime, timestamp));
        farm = address(new SoonFarming{salt : bytes32(_salt)}());
        ISoonFarming(farm).initialize(
            _msgSender(),
            _name,
            _stakeTokenAddr,
            _rewardTokenNumber,
            _rewardsDuration,
            _rewardTokens
        );
        uint256 _len = _rewardTokens.length;
        for (uint256 i = 0; i < _len; i++) {
            address rewardToken = _rewardTokens[i];
            uint256 reward = _rewards[i];
            if (reward > 0) {
                uint256 balance = IERC20(rewardToken).balanceOf(msg.sender);
                require(balance >= reward, 'FarmFactory: Reward not sufficient funds');
                IERC20(rewardToken).transferFrom(msg.sender, farm, reward);
            }
        }
        getFarm[_stakeTokenAddr].push(farm);
        allFarm.push(farm);
        emit createFarmEvent(
            farm,
            _name,
            _stakeTokenAddr,
            _rewardTokenNumber,
            _rewardTokens,
            _rewards,
            _beginTime,
            _endTime
        );
    }

}
