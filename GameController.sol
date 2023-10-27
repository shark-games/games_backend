// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SHKFI.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
//import "@openzeppelin/contracts/utils/Math.sol";

contract GameController is Ownable {
    using Address for address;
    // admin address
    //address private owner;
    // balance of tokens held in escrow
    uint256 public contractBalance;
    // this is the erc20 GameToken contract address
    address constant tokenAddress = 0x090D2d13a7fa47e5d61Eb384DFA89C6D129F099f; // <-- INSERT DEPLYED ERC20 TOKEN CONTRACT HERE
    uint256 public maxSupply = 10000000000000000000000; // <-- temporaily set manually for flexibility while in pre-alpha development
    uint256 public unit = 10000; // <-- temporaily set manually for flexibility while in pre-alpha development
     
    // game data tracking
    struct Game {
        uint256 gameId;
        address player;
        uint256 stake;
        bool locked;
        bool withdrawn;
        bool won;
        uint256 reward;
    }

    // map game to balances
    mapping(address => mapping(uint256 => Game)) public balances;
    
    // set-up event for emitting once character minted to read out values
    event NewGame(uint256 gameId, address indexed player);

    constructor() {
        
    }

    // retrieve current state of game funds in escrow
    function gameState(address _player, uint256 _gameId)
        external
        view
        returns (
            uint256,
            uint256,
            bool,
            bool,
            bool
        )
    {
        return (
            balances[_player][_gameId].stake,
            balances[_player][_gameId].reward,
            balances[_player][_gameId].withdrawn,
            balances[_player][_gameId].won,
            balances[_player][_gameId].locked
        );
    }

    // admin starts game
    // staked tokens get moved to the escrow (this contract)
    function createGame(
        address _player,
        uint256 _p,
        uint256 _r,
        uint256 gameId
    ) external returns(uint256)
    {

        SHKFI token = SHKFI(tokenAddress);
        //unit = token.unit();
                                         
        //transfer player stake to game contract        
        token.transferFrom(_player, address(this), _p);
        
        // full escrow balance (add player now, add reward when player wins
        contractBalance += (_p + _r);

        // init game data
        balances[_player][gameId].stake = (_p);
        balances[_player][gameId].reward = (_r);
        balances[_player][gameId].withdrawn = false;
        balances[_player][gameId].won = false;
        balances[_player][gameId].locked = true;
        balances[_player][gameId].player = _player;

        emit NewGame(gameId, _player);
        
        return gameId;
    }

    // game is set to won and funds are unlocked so they can be withdrawn by player
    function playerWon(address _player, uint256 _gameId)
        external
        onlyOwner
        returns (bool)
    {
        SHKFI token = SHKFI(tokenAddress);
        maxSupply = token.maxSupply();
      
        // validate winnings  - ToDo - criteria?
        require(
            balances[_player][_gameId].stake < maxSupply,
            "P2EGame: winnings exceed balance in escrow"
        );
     
        //Transfer in reward amount
        token.transferFrom(msg.sender, address(this) , balances[_player][_gameId].reward);

        //Allow for player to withdraw winnings

        // set game balance to spent and game to won
        balances[_player][_gameId].won = true;
        balances[_player][_gameId].withdrawn = false;
        balances[_player][_gameId].locked = false;

        return true;

    }

    // admin sends funds to treasury if player loses game
    function playerLost(address _player, uint256 _gameId)
        payable
        external
        onlyOwner
        returns (bool)
    {
        SHKFI token = SHKFI(tokenAddress);

        //Transfer player stake to owner wallet
        uint256 totalAmount = balances[_player][_gameId].stake;

        // transfer to treasury the balance locked in escrow
        token.transferFrom(address(this), _msgSender(), totalAmount);

        // TODO: add post-transfer funcs to `_afterTokenTransfer` to validate transfer

        // amend escrow balance (just player stake amount)
        contractBalance -= (totalAmount);

        // set withdrawn to true and won to false
        balances[_player][_gameId].won = false;
        balances[_player][_gameId].withdrawn = true;
        
        return true;
    }

function playerWithdraw(address payable _player, uint256 _gameId )
        payable
        external
        returns (bool)
    {
        address sender = msg.sender;
        uint length;
        assembly {
        length := extcodesize(sender)
        }

        if (length > 0) {
        revert("Contract addresses are not allowed!");
        }

        //If the balances array is set won == true and withdrawn == false 
        if((balances[_player][_gameId].won == true)              
            &&      
            (balances[_player][_gameId].withdrawn == false))
        {
            uint256 totalAmount = balances[_player][_gameId].stake + balances[_player][_gameId].reward;

            SHKFI token = SHKFI(tokenAddress);
            maxSupply = token.maxSupply();
  
            // validate winnings  - ToDo - criteria?
            if(totalAmount > maxSupply)
            {
                revert("Winnings exceed max supply.");
            }
            
            if (totalAmount > contractBalance)
            {
                revert("Winnings exceeed balance in escrow."); 
            }

            // amend escrow balance
            contractBalance -= totalAmount;

            // set game balance to spent and game to won
            balances[_player][_gameId].withdrawn = true;
            balances[_player][_gameId].stake = 0;
                     
            //Transfer tokens from 
            token.transferFrom(address(this), _msgSender(), totalAmount);        

        }
        else {
            revert("Options not valid for withdraw.");
        }

        return true;

    }

    function increaseAllowance(address spender, uint256 amount) 
    external 
    onlyOwner 
    {
        SHKFI token = SHKFI(tokenAddress);
        token.increaseAllowance(spender, amount);
    }

}
