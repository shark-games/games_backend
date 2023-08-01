// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SChess.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract GameController is Ownable {
    using Address for address;
    // admin address
    address private admin;
    // balance of tokens held in escrow
    uint256 public contractBalance;
    // this is the erc20 GameToken contract address
    address constant tokenAddress = ; // <-- INSERT DEPLYED ERC20 TOKEN CONTRACT HERE
    uint256 public maxSupply = 1000000000000000000000; // <-- temporaily set manually for flexibility while in pre-alpha development
    uint256 public unit = 10000; // <-- temporaily set manually for flexibility while in pre-alpha development
    uint256 public gameId;

    // game data tracking
    struct Game {
        address treasury;
        uint256 balance;
        bool locked;
        bool spent;
    }
    // map game to balances
    mapping(address => mapping(uint256 => Game)) public balances;
    // set-up event for emitting once character minted to read out values
    event NewGame(uint256 id, address indexed player);

    // only admin account can unlock escrow
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can unlock escrow.");
        _;
    }


    constructor() {
        admin = msg.sender;
        gameId = 0;
    }

    // retrieve current state of game funds in escrow
    function gameState(uint256 _gameId, address _player)
        external
        view
        returns (
            uint256,
            bool,
            address
        )
    {
        return (
            balances[_player][_gameId].balance,
            balances[_player][_gameId].locked,
            balances[_player][_gameId].treasury
        );
    }

    // admin starts game
    // staked tokens get moved to the escrow (this contract)
    function createGame(
        address _player,
        address _treasury,
        uint256 _p,
        uint256 _t
    ) external returns(uint256)
    {
        SChess token = SChess(tokenAddress);
        //unit = token.unit();
        
        token.transferFrom(msg.sender, address(this), _t);
        token.transferFrom(_player, address(this), _p);

        // full escrow balance
        contractBalance += (_p + _t);

        // iterate game identifier
        gameId++;

        // init game data
        balances[_player][gameId].balance = (_p + _t);
        balances[_player][gameId].treasury = _treasury;
        balances[_player][gameId].locked = true;
        balances[_player][gameId].spent = false;

        emit NewGame(gameId, _player);
        
        return gameId;
    }

    // admin unlocks tokens in escrow once game's outcome decided
    function playerWon(uint256 _gameId, address _player)
        external
        onlyAdmin
        returns (bool)
    {
        SChess token = SChess(tokenAddress);
        //maxSupply = token.maxSupply();

        // allows player to withdraw
        balances[_player][_gameId].locked = false;
        // validate winnings
        require(
            balances[_player][_gameId].balance < maxSupply,
            "P2EGame: winnings exceed balance in escrow"
        );
        // final winnings = balance locked in escrow + in-game winnings
        // transfer to player the final winnings
        token.transfer(_player, balances[_player][_gameId].balance);
        // TODO: add post-transfer funcs to `_afterTokenTransfer` to validate transfer

        // amend escrow balance
        contractBalance -= balances[_player][_gameId].balance;
        // set game balance to spent
        balances[_player][_gameId].spent = true;
        return true;
    }

    // admin sends funds to treasury if player loses game
    function playerLost(uint256 _gameId, address _player)
        external
        onlyAdmin
        returns (bool)
    {
        SChess token = SChess(tokenAddress);
        // transfer to treasury the balance locked in escrow
        token.transfer(
            balances[_player][_gameId].treasury,
            balances[_player][_gameId].balance
        );
        // TODO: add post-transfer funcs to `_afterTokenTransfer` to validate transfer

        // amend escrow balance
        contractBalance -= balances[_player][_gameId].balance;
        // set game balance to spent
        balances[_player][_gameId].spent = true;
        return true;
    }

    // player is able to withdraw unlocked tokens without admin if unlocked
    function withdraw(uint256 _gameId) external returns (bool) {
        require(
            balances[msg.sender][_gameId].locked == false,
            "This escrow is still locked"
        );
        require(
            balances[msg.sender][_gameId].spent == false,
            "Already withdrawn"
        );

        SChess token = SChess(tokenAddress);
        // transfer to player of game (msg.sender) the value locked in escrow
        token.transfer(msg.sender, balances[msg.sender][_gameId].balance);
        // TODO: add post-transfer funcs to `_afterTokenTransfer` to validate transfer
        // amend escrow balance
        contractBalance -= balances[msg.sender][_gameId].balance;
        // set game balance to spent
        balances[msg.sender][_gameId].spent = true;
        return true;
    }
}
