// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "./WithAdmin.sol";

abstract contract PausableWithAdmin is WithAdmin, Pausable {
    /**
     * @dev triggers stopped state.
     */
    function pause() public onlyAdmin whenNotPaused {
        _pause();
    }

    /**
     * @dev returns to normal state.
     */
    function unpause() public onlyAdmin whenPaused {
        _unpause();
    }
}
