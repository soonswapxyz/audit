// SPDX-License-Identifier: MIT
pragma solidity = 0.8.17;


interface ISoonswapPair {

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);

    event addLiquidityEvent(
        address indexed sender,
        uint256[] nfts,
        uint256 tokenAmount,
        uint256 liquidity
    );

    event removeLiquidityEvent(
        address indexed sender,
        uint256[] nfts,
        uint256 tokenAmount,
        uint256 liquidity
    );

    event depositToTokenEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256 buyPricesSum,
        uint256[] buyPrices
    );

    event editToTokenEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256 buyPricesSum,
        uint256[] buyPrices
    );


    event depositToNFTEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256[] nfts,
        uint256[] sellPrices
    );

    event editToNFTEvent(
        address indexed sender,
        uint256  indexed orderId,
        uint256[] nfts,
        uint256[] sellPrices
    );

    event Swap(
        address indexed sender,
        uint256 tokenAmount,
        uint256 tokenId,
        uint256 tokenAmountOut,
        uint256 tokenIdOut,
        uint256 txType
    );

    //event Sync(uint256 reserve0, uint256 reserve1);

    function factory() external view returns (address);

    //function token0() external view returns (address);

    //function token1() external view returns (address);

    function swapFee() external view returns (uint8);

    //function bilateral() external view returns (bool);

    //function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint32 blockTimestampLast);

    // 操作接口;
    function initialize(
        //address _token0,
        //address _token1,
        uint8 _swapFee,
        //bool _bilateral,
        address _nftContract,
        //address _orderCenter,
        address _feeToken,
        address _feeTo
    ) external;

    // 添加 移除流动性;
    function addLiquidity(uint256[] calldata _tokenIds, uint256 tokenAmount) payable external returns (uint256 liquidity);

    function removeLiquidity(uint256 lpAmount,uint256[] memory _nfts) payable external returns (uint256 _nftAmount, uint256 _tokenAmount);

    // swap;
    function swap(uint256[] memory _tokenAmounts, uint256[] memory _tokenIds, uint256 txType)payable external;
}
