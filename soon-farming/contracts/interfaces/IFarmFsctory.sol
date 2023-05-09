// SPDX-License-Identifier: AGPL-3.0
pragma solidity = 0.8.17;


interface IFarmFsctory {
    function isAccountBlocked(address account) external view returns (bool);
}
