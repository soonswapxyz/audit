// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface INFTWhiteList {
    function list(address nftAddr) external view returns (bool);
}
