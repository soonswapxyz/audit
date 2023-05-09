//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;


import {IERC20} from  "@openzeppelin/contracts/token/ERC20/IERC20.sol";


library TransferLib {

    function safeTransfer(address token, address to, uint256 value) internal {
        (bool callSuccess, bytes memory callReturnValueEncoded) = token.call(abi.encodeWithSignature("transfer(address,uint256)", to, value));
        bool returnedSuccess = callReturnValueEncoded.length == 0 || abi.decode(callReturnValueEncoded, (bool));
        require(callSuccess && returnedSuccess, 'Soonswap: TRANSFER_FAILED');
    }

    function safeTransferETH(address to, uint256 amount) internal {
        bool callStatus;
        assembly {
            callStatus := call(gas(), to, amount, 0, 0, 0, 0)
        }
        require(callStatus, "ETH_TRANSFER_FAILED");
    }

    function mintERC20(address _token, address _to, uint256 _amount) internal returns (bool) {
        (bool callSuccess, bytes memory callReturnValueEncoded) =  _token.call(abi.encodeWithSignature("mint(address,uint256)", _to, _amount));
        bool returnedSuccess = callReturnValueEncoded.length == 0 || abi.decode(callReturnValueEncoded, (bool));
        return callSuccess && returnedSuccess;
    }

    function burnERC20(address _token, address _to, uint256 _amount ) internal returns (bool) {
        (bool callSuccess, bytes memory callReturnValueEncoded) = _token.call(abi.encodeWithSignature("burn(address,uint256)", _to, _amount));
        bool returnedSuccess = callReturnValueEncoded.length == 0 || abi.decode(callReturnValueEncoded, (bool));
        return callSuccess && returnedSuccess;
    }


    function approve( address _token, address spender, uint256 _amount) internal returns (bool) {
        (bool callSuccess, bytes memory callReturnValueEncoded) = _token.call(abi.encodeWithSignature("approve(address,uint256)", spender, _amount));
        bool returnedSuccess = callReturnValueEncoded.length == 0 || abi.decode(callReturnValueEncoded, (bool));
        return callSuccess && returnedSuccess;
    }

    function transferFrom(address _token, address _from, address _to, uint256 _amount) internal returns (bool) {
        (bool callSuccess, bytes memory callReturnValueEncoded) = _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", _from, _to, _amount));
        bool returnedSuccess = callReturnValueEncoded.length == 0 || abi.decode(callReturnValueEncoded, (bool));
        return callSuccess && returnedSuccess;
    }

    function setApprovalForAll( address _token, address _spender, bool _approved) internal  {
        (bool callSuccess, bytes memory callReturnValueEncoded) = _token.call(abi.encodeWithSignature("setApprovalForAll(address,bool)", _spender, _approved));
        bool returnedSuccess = callReturnValueEncoded.length == 0 || abi.decode(callReturnValueEncoded, (bool));
        require(callSuccess && returnedSuccess, 'Soonswap: SETAPPROVALFORALL_FAILED');
    }
}
