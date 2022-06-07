//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import './libraries/FundingUtils.sol';
import './libraries/Strings.sol';
import './ProjectToken.sol';
import "hardhat/console.sol";

/// @title A upgradable and pausable crowdfunding contract for every project
/// @author Hosokawa Zen
/// @notice You can use this contract as a template for every crowdfunding project
contract CrowdFunding is PausableUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMath for uint256;
    using Strings for string;

    struct FundData {
        uint256 tokenAmount;
        uint256 fundAmount;
    }

    /// Mapping of investor`s address => stable coin`s address => fund amount
    mapping(address => mapping(address => FundData)) public contributionsMap;
    uint256 private totalDepositTokenAmount;
    uint256 private totalReserveAmount;

    /// stable coin`s address => Reserve Amount
    mapping(address => uint256) private reserveAmount;
    /// stable coin`s address => Project Fee Amount
    mapping(address => uint256) private projectFeeAmount;
    /// stable coin`s address => Protocol Fee Amount
    mapping(address => uint256) private protocolFeeAmount;

    // Project Token
    address public projectToken;

    // Address of the deployed Project Coin contract
    address private coinAddress;
    // Project Coin`s Init Price
    uint256 private coinInitPrice;
    // Funding Project Coin`s Supply Amount
    uint256 private fundingSupplyAmount;


    // Address of secure wallet to send crowdfund contributions to
    address public walletAddress;
    // THEIA treasury address
    address public treasuryAddress;

    // MIN. Funding Threshold
    uint256 public minFundingThreshold;
    // GMT timestamp of when the crowdfund starts
    uint256 public startTimestamp;
    // GMT timestamp of when the crowdfund ends
    uint256 public endTimestamp;

    // USDT, USDC
    mapping(address => bool) public stableCoins;

    uint16 internal constant PERCENT_DIVISOR = 10 ** 4;
    uint16 internal constant PROTOCAL_FEE_PERCENT = 30;
    uint16 internal constant PROJECT_OWNER_FEE_PERCENT = 70;

    // Sell price coefficient (0.9)
    uint16 internal constant SELL_CURVE_COEFFICIENT_PERCENT = 9000;

    /**
     * ****************************************
     *
     * Events
     * ****************************************
     */
    // Investor Withdraw Fund
    event IWithdrawFund(address indexed investor, address indexed stableCoin, uint256 amount);
    // Investor ReClaim Fund
    event IReclaimFund(address indexed investor, address indexed stableCoin, uint256 amount);
    // Investor Claim Fund
    event IClaimFund(address indexed investor, address indexed stableCoin, uint256 amount);
    // Investor Claim Coin
    event IClaimCoin(address indexed investor, address indexed stableCoin, uint256 amount);

    // Investor Claim Coin
    event WithdrawCoin(uint256 amount);
    // Investor Claim Coin
    event ClaimFees(address indexed stableCoin, uint256 amount);
    // Investor Claim Coin
    event ClaimFund(address indexed stableCoin, uint256 amount);

    // Claim Fees
    event TClaimFees(address indexed stableCoin, uint256 amount);

    /**
     * ****************************************
     *
     * Modifiers
     * ****************************************
     */
    // Crowd Funding is active when project owner sends enough project coins to funding contracts
    modifier crowdFundIsActive() {
        require(coinInitPrice * IERC20(coinAddress).balanceOf(address(this)) > minFundingThreshold, "Project Coin is not enough");
        _;
    }

    // Ensure actions can only happen while crowdfund is ongoing
    modifier crowdFundIsOngoing() {
        require(block.timestamp >= startTimestamp && block.timestamp < endTimestamp, "Funding is not ongoing");
        _;
    }

    // Ensure actions can only happen after crowdfund ends
    modifier crowdFundIsStart(){
        require(block.timestamp >= startTimestamp, "Funding still did not start");
        _;
    }

    // Ensure actions can only happen after crowdfund ends
    modifier crowdFundIsEnd(){
        require(block.timestamp >= endTimestamp, "Funding still did not end");
        _;
    }

    // Ensure actions can only happen when funding threshold is reached
    modifier fundingReachedToTh(){
        require(totalReserveAmount >= minFundingThreshold, "Funding was not reached to Min Threshold");
        _;
    }

    // Ensure actions can only happen when funding threshold is not reached
    modifier fundingNotReachedToTh(){
        require(totalReserveAmount < minFundingThreshold, "Funding reached Min Threshold");
        _;
    }

    /**
     * ****************************************
     *
     * Constructor
     * ****************************************
     */
    /// Upgradable Initializer
    /// @param _coinAddress             Funding Token Address
    /// @param _coinInitPrice           Funding Coin Address
    /// @param _startTimestamp          GMT Timestamp of starting funding ex: 1609459200 -> 2021/1/1 0:0:0 (GMT)
    /// @param _endTimestamp            GMT Timestamp of ending funding ex: 1609459200 -> 2021/1/1 0:0:0 (GMT)
    /// @param _minFundingThreshold     Min Funding Threshold Amount.
    function initialize(string memory _pName, address _coinAddress, uint256 _coinInitPrice, uint256 _startTimestamp, uint256 _endTimestamp, uint256 _minFundingThreshold) public initializer{
        require(_pName.length() > 2, "Project Name Min Length: 3");
        require(_pName.length() < 13, "Project Name Max Length: 12");
        require(_startTimestamp < _endTimestamp, "Start timestamp < End Timestamp");
        require(_minFundingThreshold > 0, "MIN.Threshold must be greater than zero");
        require(_coinInitPrice > 0, "Coin Price must be greater than zero");

        coinAddress = _coinAddress;
        coinInitPrice = _coinInitPrice;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        minFundingThreshold = _minFundingThreshold;

        treasuryAddress = 0xaFA6058126D8f48d49A9A4b127ef7e27C5e1DC43;

        /// Unique Project Token
        /// Name: Project Name
        /// Symbol: Protocal Prefer (T) + Project Name (Max 6 letters)
        string memory tokenName = _pName.upper();
        string memory tokenSymbol = string("T").append(tokenName.slice(0, 6).upper());
        projectToken = address(new ProjectToken(tokenName, tokenSymbol));

        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /**
     * ****************************************
     *
     * Public Functions
     * ****************************************
     */

    /// Set min. funding threshold
    function setMinFundingThreshold(uint256 _minFundingThreshold) public onlyOwner {
        require(_minFundingThreshold > 0, "MIN.Threshold must be greater than zero");
        minFundingThreshold = _minFundingThreshold;
    }

    /// Set start timestamp of crowd funding
    function setStartTimestamp(uint256 _startTimestamp) public onlyOwner {
        require(block.timestamp < startTimestamp, "Funding already started");
        require(_startTimestamp < endTimestamp, "Start timestamp < End Timestamp");

        startTimestamp = _startTimestamp;
    }

    /// Set end timestamp of crowd funding
    function setEndTimestamp(uint256 _endTimestamp) public onlyOwner {
        require(block.timestamp < endTimestamp, "Funding already ended");
        require(startTimestamp < _endTimestamp, "Start timestamp < End Timestamp");

        endTimestamp = _endTimestamp;
    }

    // Set Stable Coin
    function setStableCoin(address _coinAddress) public onlyOwner {
        stableCoins[_coinAddress] = true;
    }

    // Set Wallet Address fro Project fee
    function setWalletAddress(address _walletAddress) public onlyOwner {
        walletAddress = _walletAddress;
    }

    // Project Owner allocate Project Coin to this contract
    function allocateSupply(uint256 amount) public onlyOwner nonReentrant {
        // Project owner sends project coins to funding contract
        IERC20(coinAddress).transferFrom(msg.sender, address(this), amount);
        fundingSupplyAmount = fundingSupplyAmount.add(amount);
    }

    /// Get Token`s Buy Price
    /// @notice This depends on Bonding buy curve equation.
    function getBuyPrice(uint256 investAmount) public view returns (uint256){
        //console.log('price calculation: initPrice %s %s %s', coinInitPrice, fundingSupplyAmount, totalReserveAmount + investAmount);
        return FundingUtils._calculatePrice(coinInitPrice, fundingSupplyAmount, totalReserveAmount + investAmount);
    }

    /// Get Token`s Sell Price
    /// @notice This depends on Bonding sell curve equation.
    /// @dev SELL_CURVE_COEFFICIENT * Buy Price
    function getSellPrice(uint256 investAmount) public view returns (uint256){
        return FundingUtils._calculatePrice(coinInitPrice, fundingSupplyAmount, totalReserveAmount + investAmount).mul(SELL_CURVE_COEFFICIENT_PERCENT).div(PERCENT_DIVISOR);
    }

    /**
     * ****************************************
     *
     * Investor`s Roles
     * ****************************************
     */

    /// Invest
    /// @param _stableCoin Investing StableCoin`s Address
    /// @param _investAmount Investing StableCoin`s Amount
    function iinvest(address _stableCoin, uint256 _investAmount) public nonReentrant whenNotPaused crowdFundIsActive crowdFundIsOngoing {

        require(stableCoins[_stableCoin] == true, "StableCoin is unavailable");
        require(IERC20(_stableCoin).balanceOf(msg.sender) >= _investAmount, "Coin is not enough");

        // Protocol Fee during investment
        uint256 _protocolFeeAmount = _investAmount.mul(PROTOCAL_FEE_PERCENT).div(PERCENT_DIVISOR);
        protocolFeeAmount[_stableCoin] = protocolFeeAmount[_stableCoin].add(_protocolFeeAmount);

        // Project Owner Fee during investment
        uint256 _projectFeeAmount = _investAmount.mul(PROJECT_OWNER_FEE_PERCENT).div(PERCENT_DIVISOR);
        projectFeeAmount[_stableCoin] = projectFeeAmount[_stableCoin].add(_projectFeeAmount);

        // Investing Amount
        uint256 investAmount = _investAmount.sub(_protocolFeeAmount).sub(_projectFeeAmount);

        uint256 investPrice = getBuyPrice(investAmount);
        // Not allow zero price because of too small invest amount
        require(investAmount > 0, "Too small invest amount");
        // Project Token Amount for providing to investor
        uint256 ptAmount = investAmount.div(investPrice);

        // Send StableCoin from investor to contract
        IERC20(_stableCoin).transferFrom(msg.sender, address(this), _investAmount);

        // Set Total data
        totalReserveAmount = totalReserveAmount.add(investAmount);
        reserveAmount[_stableCoin] = reserveAmount[_stableCoin].add(investAmount);
        totalDepositTokenAmount = totalDepositTokenAmount.add(ptAmount);

        // Set Map data
        contributionsMap[msg.sender][_stableCoin].fundAmount = contributionsMap[msg.sender][_stableCoin].fundAmount.add(investAmount);
        contributionsMap[msg.sender][_stableCoin].tokenAmount = contributionsMap[msg.sender][_stableCoin].tokenAmount.add(ptAmount);

        // Mint Project Token and Transfer to investor
        IProjectToken(projectToken).mint(msg.sender, ptAmount);
    }

    /// Withdraw
    function iwithdrawFund(address _stableCoin) public nonReentrant whenNotPaused crowdFundIsOngoing {
        uint256 fundAmount = contributionsMap[msg.sender][_stableCoin].fundAmount;
        uint256 investorTokens = contributionsMap[msg.sender][_stableCoin].tokenAmount;
        require(investorTokens > 0, "No Funded Amount");

        // Burn Project Token
        IProjectToken(projectToken).transferFrom(msg.sender, address(this), investorTokens);
        IProjectToken(projectToken).burn(investorTokens);

        // Return StableCoin to investor
        IERC20(_stableCoin).transfer(msg.sender, fundAmount);

        // Reset Map Data
        contributionsMap[msg.sender][_stableCoin].tokenAmount = 0;
        contributionsMap[msg.sender][_stableCoin].fundAmount = 0;

        // Set Total data
        totalReserveAmount = totalReserveAmount.sub(fundAmount);
        reserveAmount[_stableCoin] = reserveAmount[_stableCoin].sub(fundAmount);
        totalDepositTokenAmount = totalDepositTokenAmount.sub(investorTokens);

        emit IWithdrawFund(msg.sender, _stableCoin, fundAmount);
    }

    /// Reclaim
    /// @notice (when the min. funding threshold is NOT reached within the timeline)
    function ireclaimFund(address _stableCoin) public nonReentrant whenNotPaused crowdFundIsEnd fundingNotReachedToTh {

        uint256 fundAmount = contributionsMap[msg.sender][_stableCoin].fundAmount;
        uint256 investorTokens = contributionsMap[msg.sender][_stableCoin].tokenAmount;
        require(investorTokens > 0, "No Funded Amount");

        // Burn Project Token
        IProjectToken(projectToken).transferFrom(msg.sender, address(this), investorTokens);
        IProjectToken(projectToken).burn(investorTokens);

        // Return StableCoin to investor
        IERC20(_stableCoin).transfer(msg.sender, fundAmount);

        // Reset Map Data
        contributionsMap[msg.sender][_stableCoin].tokenAmount = 0;
        contributionsMap[msg.sender][_stableCoin].fundAmount = 0;

        emit IReclaimFund(msg.sender, _stableCoin, fundAmount);
    }

    /// Claim
    /// @notice (when the min. funding threshold is reached within the timeline)
    function iclaimCoin(address _stableCoin) public nonReentrant whenNotPaused crowdFundIsEnd fundingReachedToTh {
        uint256 investorTokens = contributionsMap[msg.sender][_stableCoin].tokenAmount;
        require(investorTokens > 0, "No Funded Amount");

        // Project Tokens => Project Coin
        uint256 coinAmount = fundingSupplyAmount.mul(investorTokens).div(totalDepositTokenAmount);

        // Burn Project Token
        IProjectToken(projectToken).transferFrom(msg.sender, address(this), investorTokens);
        IProjectToken(projectToken).burn(investorTokens);

        // Send Project Coin to investor
        IERC20(coinAddress).transfer(msg.sender, coinAmount);

        // Reset Map Data
        contributionsMap[msg.sender][_stableCoin].tokenAmount = 0;
        contributionsMap[msg.sender][_stableCoin].fundAmount = 0;

        emit IClaimCoin(msg.sender, _stableCoin, coinAmount);
    }


    /**
     * ****************************************
     *
     * Project Owner`s Roles
     * ****************************************
     */

    /// Withdraw
    /// @notice (when the min. funding threshold is NOT reached within the timeline.)
    function withdrawCoin() public onlyOwner nonReentrant whenNotPaused crowdFundIsEnd fundingNotReachedToTh {
        IERC20(coinAddress).transfer(msg.sender, fundingSupplyAmount);
        emit WithdrawCoin(fundingSupplyAmount);
    }

    /// Claim Fee
    /// @notice (when the min. funding threshold is reached within the timeline)
    function claimFees(address _stableCoin) public onlyOwner nonReentrant whenNotPaused crowdFundIsStart fundingReachedToTh {
        require(walletAddress != address(0), "Reward address can not be ZERO_ADDRESS");

        uint256 feeAmount = projectFeeAmount[_stableCoin];
        require(feeAmount > 0, "No Fee");

        IERC20(_stableCoin).transfer(walletAddress, feeAmount);
        projectFeeAmount[_stableCoin] = 0;

        emit ClaimFees(_stableCoin, feeAmount);
    }

    /// Claim Fund
    /// @notice (when the min. funding threshold is reached within the timeline)
    function claimFund(address _stableCoin) public onlyOwner nonReentrant whenNotPaused crowdFundIsEnd fundingReachedToTh {
        require(walletAddress != address(0), "Reward address can not be ZERO_ADDRESS");

        uint256 claimAmount = reserveAmount[_stableCoin];
        require(claimAmount > 0, "No Amount");

        IERC20(_stableCoin).transfer(walletAddress, claimAmount);

        reserveAmount[_stableCoin] = 0;
        totalReserveAmount = totalReserveAmount.sub(claimAmount);

        emit ClaimFund(_stableCoin, claimAmount);
    }

    /**
     * ****************************************
     *
     * Protocol owner roles
     * ****************************************
     */

    function tclaimFees(address _stableCoin) public nonReentrant whenNotPaused crowdFundIsStart fundingReachedToTh {
        uint256 feeAmount = protocolFeeAmount[_stableCoin];
        require(feeAmount > 0, "No Fee");

        IERC20(_stableCoin).transfer(treasuryAddress, feeAmount);
        protocolFeeAmount[_stableCoin] = 0;

        emit TClaimFees(_stableCoin, feeAmount);
    }

    /**
     * ****************************************
     *
     * Implemented from PausableUpgradeable
     * ****************************************
     */

    /// @notice Pause contract
    function pause() public onlyOwner whenNotPaused {
        _pause();
    }

    /// @notice Unpause contract
    function unpause() public onlyOwner whenPaused {
        _unpause();
    }
}
