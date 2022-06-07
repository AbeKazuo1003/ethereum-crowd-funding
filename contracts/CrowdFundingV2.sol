//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CrowdFunding.sol";

/// @title CrowdFunding Version 2
/// @author Hosokawa Zen
/// @dev Add function for setting treasury address
contract CrowdFundingV2 is CrowdFunding {

    /// @notice set treasury Address
    function setTreasuryAddress(address _treasuryAddress) external {
        require(treasuryAddress == _msgSender(), "No Permission");
        treasuryAddress = _treasuryAddress;
    }
}
