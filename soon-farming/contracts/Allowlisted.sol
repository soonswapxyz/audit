// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


abstract contract Allowlisted {

    // Emitted when an address is blocked(not allowed to transfer).
    event Block(address indexed addr);

    // Emitted when an address is unblocked(re-allow to transfer), any account is allowed to transfer by default.
    event Unblock(address indexed addr);

    // The block list.
    // True if the address is not allowed to transfer.
    mapping(address => bool) private _blocklist;

    // Block account, applying to an blocked addr will not have any impact.
    function _blockAddress(address addr) internal virtual{
        if (!IsAccountBlocked(addr)) {
            _blocklist[addr] = true;
        }

        emit Block(addr);
    }

    function _unblockAddress(address addr) internal virtual{
        if (IsAccountBlocked(addr)) {
            _blocklist[addr] = false;
        }

        emit Unblock(addr);
    }

    function IsAccountBlocked(address addr) public virtual view returns(bool){
        return _blocklist[addr];
    }
}
