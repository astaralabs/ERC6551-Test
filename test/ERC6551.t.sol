// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/ERC6551Account.sol";
import "../src/ERC6551Registry.sol";
import "../src/MyNFT.sol";
import "../src/MyToken.sol";

contract CounterTest is Test {
    // Counter public counter;
    ERC6551Account account;
    ERC6551Registry registry;
    MyNFT nftContract; 
    MyToken tokenContract;

    address deployer;
    address account1;
    address account2;

    function setUp() public {
        // Create two addresses from a fool mnemonic 
        string memory mnemonic = "test test test test test test test test test test test junk";
        uint256 deployerPrivateKey = vm.deriveKey(mnemonic, 0);
        uint256 account1PrivateKey = vm.deriveKey(mnemonic, 1);
        uint256 account2PrivateKey = vm.deriveKey(mnemonic, 2);

        deployer = vm.addr(deployerPrivateKey);
        account1 = vm.addr(account1PrivateKey);
        account2 = vm.addr(account2PrivateKey);

        console.log("Deployer address: ", deployer);
        console.log("Account1 address: ", account1);
        console.log("Account2 address: ", account2);

        //Smart contracts deployment
        vm.startPrank(deployer); //Set deployer as tx sender
        account = new ERC6551Account();
        console.log("ERC6551Account address: ", address(account));
        
        registry = new ERC6551Registry();
        console.log("ERC6551Registry address: ", address(registry));

        nftContract = new MyNFT();
        console.log("MyNFT address: ", address(nftContract));

        tokenContract = new MyToken();
        console.log("MyToken address: ", address(tokenContract));

        vm.stopPrank();

    }

    function test() public {
        vm.startPrank(deployer); //Set deployer as tx sender

        //1. Mint NFT for account1
        nftContract.safeMint(account1, 1);
        uint256 accoutn1Balance = nftContract.balanceOf(account1);
        assertEq(accoutn1Balance, 1); //account1 balance = 1
        
        //2. Deploy the NFT "wallet"
        address nftAccount = registry.createAccount(
                                        address(account), //implementation (Account contract)
                                        block.chainid, //chainId
                                        address(nftContract), //tokenContract
                                        1, //TokenId
                                        0, //salt
                                        hex"" //initData
                                    );
        console.log("nftAccount: ", nftAccount);
        
        //Check the NFT wallet owner
        //nftAccount must be payable because ERC6551 contract has a receive payable function
        ERC6551Account NFTWalletAccount = ERC6551Account(payable(nftAccount)); //Get the deployed account
        address accountOwner = NFTWalletAccount.owner();
        assertEq(accountOwner, account1); //Account1 is the owner of the NFT wallet (ERC6551Account)

        //Check which NFT the wallet belongs to
        (, , uint256 tokenIdWallet) = NFTWalletAccount.token();
        assertEq(tokenIdWallet, 1); //The tokenId of this wallet is the first one
        
        //3. Mint 50 ERC20 tokens
        tokenContract.mint(50 ether);
        uint256 deployerBalance = tokenContract.balanceOf(deployer);
        assertEq(deployerBalance, 50 ether);

        //4. Send 50 ERC20 tokens to the NFT 1 wallet (ERC6551Account)
        tokenContract.transfer(nftAccount, 50 ether);
        uint256 nftAccountBalance = tokenContract.balanceOf(nftAccount);
        assertEq(nftAccountBalance, 50 ether); //The NFT wallet has 50 Tokens

        //Check now the deployer's balance
        deployerBalance = tokenContract.balanceOf(deployer);
        assertEq(deployerBalance, 0 ether); //The deployer owns 0 tokens

        //5. account1 sends 10 tokens from the wallet to his personal account
        vm.startPrank(account1); //Set deployer as tx sender
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", account1, 10 ether); //Tx to execute from the wallet
        NFTWalletAccount.executeCall(
                            address(tokenContract), //to (Target contract)
                            0, //Value in ETH
                            data //Function that we want to execute on target contract
                        );
        nftAccountBalance = tokenContract.balanceOf(nftAccount);
        assertEq(nftAccountBalance, 40 ether); //Wallet has 40 tokens

        uint256 account1TokenBalance = tokenContract.balanceOf(account1);
        assertEq(account1TokenBalance, 10 ether);

        //6. account1 transfers the NFT 1 (transferring their wallet and the ERC20 tokens) to account2
        nftContract.transferFrom(account1, account2, 1);
        uint256 account2Balance = nftContract.balanceOf(account2);
        assertEq(account2Balance, 1);
        
        accoutn1Balance = nftContract.balanceOf(account1);
        assertEq(accoutn1Balance, 0); //account1 balance = 0

        //7. Account2 can call executeCall because he is the token owner
        vm.startPrank(account2); //Set account2 as tx sender
        data = abi.encodeWithSignature("transfer(address,uint256)", account2, 10 ether);
        NFTWalletAccount.executeCall(
                            address(tokenContract), //to (Target contract)
                            0, //Value in ETH
                            data //Function that we want to execute on target contract
                        );
        nftAccountBalance = tokenContract.balanceOf(nftAccount);
        assertEq(nftAccountBalance, 30 ether); //Wallet has 30 tokens

        uint256 account2TokenBalance = tokenContract.balanceOf(account2);
        assertEq(account2TokenBalance, 10 ether);

        //8. Account1 can't execute a call because he is not the token owner
        vm.startPrank(account1); //Set account2 as tx sender
        data = abi.encodeWithSignature("transfer(address,uint256)", account1, 30 ether);
        vm.expectRevert("Not token owner");
        NFTWalletAccount.executeCall(
                            address(tokenContract), //to (Target contract)
                            0, //Value in ETH
                            data //Function that we want to execute on target contract
                        );

        vm.stopPrank();
    }
}
