//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("TestToken", "TEST"){}

    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
}