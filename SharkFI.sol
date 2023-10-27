/*
* Tokenomics
*
*  Name  - SharkFi
*  Symbol - SHKFI
*  MAX Supply -  ?
*  Selling tax 3% 
*  3% selling tax 
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract SHKFI is Context, Ownable, ERC20 {
    // admin address
    address private admin;

    address private treasuryWallet = 0x646549A84792c998c0cd8A6bF633aFa06B016e86;
    // set max circulation of tokens: 100000000000000000000
    uint256 private _maxSupply = 10000 * (10**uint256(decimals()));
    //uint256 private_totalSupply = 10000 * (10**uint256(decimals()));
    uint256 private _unit = 10**uint256(decimals());
    uint256 public _taxFee = 30;
    //uint256 private _balances;
    mapping (address => uint256) private _balances;

    // only admin account can unlock escrow
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can mint tokens.");
        _;
    }

    /**
     * @dev Returns max supply of the token.
     */
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev Returns single unit of account.
     */
    function unit() public view returns (uint256) {
        return _unit;
    }

    /**
     * @dev Constructor that gives _msgSender() all of existing tokens.
     */
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        admin = msg.sender;

        // init circulation
        mint();
        _balances[msg.sender] = _maxSupply;

    }

    function mint() public onlyAdmin {
        _mint(msg.sender, _maxSupply);
    }

    // player must approve allowance for escrow/P2EGame contract to use (spender)
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        //amount = _maxSupply; // <-- 100 by default which is max supply
    
        _approve(owner, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) 
    public 
    override 
    returns (bool) 
    {
        _transferstandard(_msgSender(), recipient, amount);

        return true;
    }

    function _transferstandard(address sender, address recipient, uint256 amount) 
    private 
    {    

        uint256 feeFirst = amount * _taxFee;
        uint256 fee = feeFirst / 1000;
        //uint256 fee = feeFirst;

        uint256 senderBalance = _balances[sender];
        //todo fix 
        //require(senderBalance >= amount, "transfer amount exceeds balance");

        _balances[sender] = senderBalance - amount;
        uint256 amountnew = amount - fee;
        _balances[recipient] += (amountnew);

        //If the fee is greater than transfer to the treasury wallet
        if (fee>0) 
        {
            _balances[treasuryWallet] += (fee);      

            _transfer(_msgSender(),treasuryWallet, fee);    
            
            //emit Transfer(_msgSender(), treasuryWallet, fee);
        }

        _transfer(_msgSender(), recipient, amountnew); 

    //emit Transfer(_msgSender(), recipient, amountnew);
  }

}

