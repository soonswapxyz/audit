// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


import "./interfaces/IFarmFsctory.sol";
import "./interfaces/ISoonFarming.sol";
import "./common/PausableWithAdmin.sol";

contract SoonFarming is
ISoonFarming,
ReentrancyGuard,
PausableWithAdmin
{

    using SafeMath for uint256;
    using Address for address;
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    uint256 public constant RATIO_BASE = 1e6;

    struct RewardInfo {
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 rewardAmount;
    }

    struct UserRewardInfo {
        address token;
        uint256 amount;
    }

    struct StakeInfo {
        uint256 totalStake;
        uint256 userStake;
        uint256 ratio;
    }

    string private _name;

    address public factory;

    uint rewardTokenNumber;

    /**
    * @dev Staking token
     */
    IERC20 public stakingToken;

    /**
     * @dev Record the rewards tokens
     */
    address[] public rewardTokens;

    /**
     * @dev Period finish
     */
    uint256 public periodFinish;

    /**
     * @dev Start Time
     */
    uint256 public startTime;

    /**
     * @dev Rewards duration
     */
    uint256 public rewardsDuration;

    /**
     * @dev total  stake
     */
    uint256 private _totalSupply;

    /**
     * @dev Record the amount staking by the user
     */
    mapping(address => uint256) private _balances;

    /**
     * @dev Record the reward data
     */
    mapping(address => RewardInfo) public rewardData;


    /**
     * @dev Record the rewards of each token
     */
    mapping(address => mapping(address => uint256)) public rewards;

    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;


    /* ========== CONSTRUCTOR ========== */

    constructor(
    ) {
        factory = msg.sender;
        _setupAdmin(msg.sender);
    }


    /**
     * @param _stakingToken staking Token
     * @param _rewardsDuration rewards duration
     * @param _rewardTokens reward tokens
     */
    function initialize(
        address _admin,
        string memory name_,
        address _stakingToken,
        uint _rewardTokenNumber,
        uint256 _rewardsDuration,
        address[] memory _rewardTokens
    ) external onlyAdmin {
        _name = name_;
        startTime = block.timestamp;
        rewardTokenNumber = _rewardTokenNumber;
        periodFinish = 0;
        _setStakingToken(_stakingToken);
        _setRewardsDuration(_rewardsDuration);
        _initRewardTokens(_rewardTokens);
        _setupAdmin(_admin);
    }

    function _initRewardTokens(address[] memory _rewardTokens) private {
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            rewardTokens.push(_rewardTokens[i]);
        }
    }

    /* ========== VIEWS ========== */

    function getTotalStake() external view returns (uint256) {
        return _totalSupply;
    }

    function getUserStake(address account) external view returns (uint256) {
        return _balances[account];
    }

    function getaAtivityTime() external view returns (uint256, uint256){
        return (periodFinish - rewardsDuration, periodFinish);
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function getStakeInfo(address account) public view returns (StakeInfo memory) {
        uint256 _userStake = _balances[account];
        if (_totalSupply == 0) {
            return StakeInfo(_userStake, 0, 0);
        }
        uint256 _ratio = _userStake * RATIO_BASE / _totalSupply;
        StakeInfo memory _info = StakeInfo(_totalSupply, _userStake, _ratio);
        return _info;
    }


    function getRewardInfo(address account) public view returns (UserRewardInfo[] memory){
        uint256 _len = rewardTokens.length;
        UserRewardInfo[] memory _rewardInfo = new UserRewardInfo[](_len);
        for (uint256 i = 0; i < _len; i++) {
            address _rewardToken = rewardTokens[i];
            uint256 _reward = rewards[account][_rewardToken];
            _reward += earned(account, _rewardToken);
            UserRewardInfo memory _info = UserRewardInfo({
            token : _rewardToken,
            amount : _reward
            });
            _rewardInfo[i] = _info;
        }
        return _rewardInfo;
    }

    function getTotalReward() public view returns (address[] memory, uint256[] memory){
        uint256 _len = rewardTokens.length;
        uint256[] memory _totalRewards = new uint256[](_len);
        address[] memory _tokens = new address[](_len);
        for (uint256 i = 0; i < _len; i++) {
            address rewardToken = rewardTokens[i];
            RewardInfo storage r = rewardData[rewardToken];
            _totalRewards[i] = r.rewardAmount;
            _tokens[i] = rewardToken;
        }
        return (_tokens, _totalRewards);
    }

    function farmPause() public onlyAdmin {
        _pause();
    }

    function farmUnpause() public onlyAdmin {
        _unpause();
    }

    function setRewardTokens(address[] memory _rewardTokens) external onlyAdmin {
        uint256 _len = _rewardTokens.length;
        require(_len > 0, "PointsStaking: Reward tokens can not be empty");
        for (uint256 i = 0; i < _len; i++) {
            require(_rewardTokens[i] != address(0), "PointsStaking: Reward token address cannot be zero");
            require(_rewardTokens[i].isContract(), "PointsStaking: Reward token  address must be contract");
        }
        _setRewardTokens(_rewardTokens);
    }

    function setStakingToken(address _stakingToken) external onlyAdmin {
        require(_stakingToken != address(0), "PointsStaking: Points address cannot be zero");
        require(_stakingToken.isContract(), "PointsStaking: The accepted address must be contract");
        _setStakingToken(_stakingToken);
    }


    function setRewardsDuration(uint256 _rewardsDuration) external onlyAdmin {
        require(
            block.timestamp > periodFinish,
            "PointsStaking: Previous rewards period must be complete before changing the duration for the new period"
        );
        require(_rewardsDuration > 0, "PointsStaking: Rewards duration verification failed");
        _setRewardsDuration(_rewardsDuration);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    function _setRewardTokens(address[] memory _rewardTokens) private {
        rewardTokens = _rewardTokens;
        emit SetRewardTokens(_rewardTokens);
    }

    function _setStakingToken(address _stakingToken) private {
        stakingToken = IERC20(_stakingToken);
        emit SetStakingToken(_stakingToken);
    }

    function _setRewardsDuration(uint256 _rewardsDuration) private {
        rewardsDuration = _rewardsDuration;
        emit SetRewardsDuration(_rewardsDuration);
    }

    function _farmBlocked(address account) private view returns (bool){
        return IFarmFsctory(factory).isAccountBlocked(account);
    }

    /**
     * @notice Add Operator
     * @param operator Operator address
     */
    function addOperator(address operator) external onlyAdmin {
        grantRole(OPERATOR_ROLE, operator);
        emit AddOperator(operator);
    }

    /**
     * @notice Remove Operator
     * @param operator Operator address
     */
    function removeOperator(address operator) external onlyAdmin {
        revokeRole(OPERATOR_ROLE, operator);
        emit RemoveOperator(operator);
    }

    /**
     * @notice Statistical user rewards
     * @param account account
     * @param rewardToken reward token
     */
    function earned(address account, address rewardToken) public view returns (uint256) {
        uint256 stakedBalance = _balances[account];
        uint256 rewardPerTokenStored = rewardPerToken(rewardToken);
        return stakedBalance.mul(rewardPerTokenStored.sub(userRewardPerTokenPaid[account][rewardToken])).div(1e18).add(rewards[account][rewardToken]);

    }

    /**
     * @notice Bonus settlement deadline
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @notice Basis of reward
     * @param rewardToken reward token
     */
    function rewardPerToken(address rewardToken) public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardData[rewardToken].rewardPerTokenStored;
        }

        RewardInfo storage r = rewardData[rewardToken];
        return r.rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(r.lastUpdateTime).mul(r.rewardRate).mul(1e18).div(_totalSupply)
        );
    }

    /**
     * @notice Customer stake
     * @param amount amount address
     */
    function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
        require(!_farmBlocked(_msgSender()), "SoonFarming:They are blacklisted users");
        address sender = msg.sender;
        require(amount > 0, "PointsStaking: Amount must be greater than 0");
        _totalSupply = _totalSupply.add(amount);
        _balances[sender] = _balances[sender].add(amount);
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        emit Stake(sender, amount);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            _claimReward(rewardToken);
        }
    }

    /**
     * @notice Customer withdraw
     * @param amount amount address
     */
    function withdraw(uint256 amount) public nonReentrant whenNotPaused updateReward(msg.sender) {
        require(!_farmBlocked(_msgSender()), "SoonFarming:They are blacklisted users");
        address sender = msg.sender;
        require(amount > 0, "PointsStaking: Amount must be greater than 0");
        require(amount <= _balances[sender], "PointsStaking: The points balance pledged is insufficient");
        _balances[sender] = _balances[sender].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
        stakingToken.safeTransfer(sender, amount);
        emit Withdraw(sender, amount);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            _claimReward(rewardToken);

        }
    }

    /**
     * @notice Only claim all previous rewards
     */
    function claimRewards() public nonReentrant whenNotPaused updateReward(msg.sender) {
        require(!_farmBlocked(_msgSender()), "SoonFarming:They are blacklisted users");
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            _claimReward(rewardToken);
        }
    }

    function _claimReward(address rewardToken) private {
        address sender = msg.sender;
        uint256 reward = rewards[sender][rewardToken];
        if (reward > 0) {
            rewards[sender][rewardToken] = 0;
            IERC20(rewardToken).safeTransfer(sender, reward);
            emit ClaimReward(sender, rewardToken, reward);
        }
    }

    /**
     * @notice Operation personnel configuration reward information
     * @param _rewardTokens reward token
     * @param _rewardAmounts reward amount
     */
    function notifyRewardAmount(address[] memory _rewardTokens, uint256[] memory _rewardAmounts) public onlyAdmin updateReward(address(0)) {
        require(rewardTokens.length == _rewardAmounts.length, "PointsStaking: Parameter verification failed");
        uint256 timestamp = block.timestamp;
        bool finish = timestamp >= periodFinish;
        uint256 _len = _rewardTokens.length;
        for (uint256 i = 0; i < _len; ++i) {
            address rewardToken = _rewardTokens[i];
            uint256 rewardAmount = _rewardAmounts[i];
            require(rewardToken != address(0), "PointsStaking: Reward token address cannot be zero");
            require(rewardToken.isContract(), "PointsStaking: The accepted address must be contract");
            require(rewardAmount > 0, "PointsStaking: Reward amount must be greater than 0");
            RewardInfo storage r = rewardData[rewardToken];
            if (finish) {
                r.rewardRate = rewardAmount.div(rewardsDuration);
                r.rewardAmount = rewardAmount;
            } else {
                uint256 remaining = periodFinish.sub(timestamp);
                uint256 leftover = remaining.mul(r.rewardRate);
                r.rewardAmount = rewardAmount.add(leftover);
                r.rewardRate = rewardAmount.add(leftover).div(rewardsDuration);
            }
            uint256 balance = IERC20(rewardToken).balanceOf(address(this));
            require(r.rewardRate <= balance.div(rewardsDuration), "PointsStaking: Provided reward too high");
            r.rewardPerTokenStored = rewardPerToken(rewardToken);
            r.lastUpdateTime = timestamp;
        }
        periodFinish = timestamp.add(rewardsDuration);
        emit RewardAdded(_rewardTokens, _rewardAmounts);
    }

    /**
     * @notice Update the activity end time
     * @param timestamp new timestamp
     */
    function updatePeriodFinish(uint256 timestamp) external onlyAdmin updateReward(address(0)) {
        periodFinish = block.timestamp > timestamp ? block.timestamp : timestamp;
        emit UpdatePeriodFinish(msg.sender, timestamp);
    }


    function stopFarm() external onlyAdmin updateReward(address(0)) {
        require(periodFinish>block.timestamp,"Farm is stoped");
        periodFinish = block.timestamp;
        emit UpdatePeriodFinish(msg.sender, block.timestamp);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            RewardInfo storage r = rewardData[rewardToken];
            if(periodFinish > 0 && (startTime + rewardsDuration) > periodFinish){
                uint256 amount = r.rewardRate * (startTime + rewardsDuration - periodFinish);
                IERC20(rewardToken).safeTransfer(msg.sender, amount);
                emit Recovered(rewardToken, amount);
            }
        }    
    }

    function recoverERC20() external onlyAdmin {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            RewardInfo storage r = rewardData[rewardToken];
            if(periodFinish > 0 && (startTime + rewardsDuration) > periodFinish){
                uint256 amount = r.rewardRate * (startTime + rewardsDuration - periodFinish);
                IERC20(rewardToken).safeTransfer(msg.sender, amount);
                emit Recovered(rewardToken, amount);
            }
        }
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account)  {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];
            RewardInfo storage r = rewardData[rewardToken];
            r.rewardPerTokenStored = rewardPerToken(rewardToken);
            r.lastUpdateTime = lastTimeRewardApplicable();
            if (account != address(0)) {
                rewards[account][rewardToken] = earned(account, rewardToken);
                userRewardPerTokenPaid[account][rewardToken] = r.rewardPerTokenStored;
            }
        }
        _;
    }

    event Stake(address indexed sender, uint256 amount);
    event Withdraw(address indexed sender, uint256 amount);
    event ClaimReward(address indexed sender, address indexed token, uint256 amount);
    event RewardAdded(address[] tokens, uint256[] amounts);
    event UpdatePeriodFinish(address indexed sender, uint256 timestamp);
    event Recovered(address indexed token, uint256 amount);

    event SetRewardTokens(address[] tokens);
    event SetStakingToken(address stakingToken);
    event SetRewardsDuration(uint256 rewardsDuration);
    event AddOperator(address operator);
    event RemoveOperator(address operator);

}
