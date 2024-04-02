// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// 1. Games of rock, paper, scissors
// 2. Rooms of independent game sessions, two players per session
// 3. Rules:
//      - Rock beats scissors
//      - Paper beats rocks
//      - Scissors beat paper
// 4. IMPORTANT: players shouldn't see each other's moves before reveal
// 5. If player refuses to reveal 1 minute after both players have made their move, they lose
//      - If both players refuse to reveal, they both lose
//          - This can be triggered by anyone
// 6. Possible game outcomes: lose-lose, win-lose, tie
// 7. If player 2 doesn't make a move 1 minute after player 1 makes a move, they lose

enum Move {
    NONE,
    ROCK,
    PAPER,
    SCISSORS
}

struct Room {
    address player1;
    address player2;
    uint120 start;
    uint120 end;
    Move player1Move;
    Move player2Move;
    bytes32 hashedPlayer1Move;
    bytes32 hashedPlayer2Move;
}

struct Player {
    uint128 wins;
    uint128 losses;
}

contract RPS {
    uint256 public constant PLAYER2_PLAY_DEADLINE = 1 minutes;
    uint256 public constant PLAYERS_REVEAL_DEADLINE = 1 minutes;

    mapping(string name => Room room) public rooms;
    mapping(address addr => Player player) public players;

    event RoomStarted(string roomName, address player1, address player2);
    event MoveMade(string roomName);
    event MoveRevealed(string roomName, address player, Move move);
    event ResultRevealed(string roomName, address winner, address loser); // winner == loser == 0 means tie

    error RoomExists();
    error RoomDoesNotExist();
    error PlayerMismatch();
    error BeforeDeadline();
    error PastDeadline();
    error CannotReveal();
    error MoveMismatch();

    function start(string calldata roomName, address player2, bytes32 hashedPlayer1Move) external {
        Room storage room = rooms[roomName];
        if (room.start > 0) revert RoomExists();
        room.start = uint120(block.timestamp);
        room.player1 = msg.sender;
        room.player2 = player2;
        room.hashedPlayer1Move = hashedPlayer1Move;
        emit RoomStarted(roomName, msg.sender, player2);
    }

    function play(string calldata roomName, bytes32 hashedPlayer2Move) external {
        Room storage room = rooms[roomName];
        if (room.start == 0) revert RoomDoesNotExist();
        if (room.player2 != msg.sender) revert PlayerMismatch();
        if (room.start + PLAYER2_PLAY_DEADLINE < block.timestamp) revert PastDeadline();
        room.hashedPlayer2Move = hashedPlayer2Move;
        room.end = uint120(block.timestamp);
        emit MoveMade(roomName);
    }

    function reveal(string calldata roomName, Move move, string calldata salt) external {
        Room storage room = rooms[roomName];
        if (room.end + PLAYERS_REVEAL_DEADLINE < block.timestamp) {
            revert CannotReveal();
        }
        if (msg.sender == room.player1) {
            verifyMove(move, salt, room.hashedPlayer1Move);
            room.player1Move = move;
            emit MoveRevealed(roomName, msg.sender, move);
        } else if (msg.sender == room.player2) {
            verifyMove(move, salt, room.hashedPlayer2Move);
            room.player2Move = move;
            emit MoveRevealed(roomName, msg.sender, move);
        } else {
            revert PlayerMismatch();
        }
    }

    function settleResults(string calldata roomName) external {
        Room storage room = rooms[roomName];
        if (room.end + PLAYERS_REVEAL_DEADLINE > block.timestamp) revert BeforeDeadline();
        (address winner, address loser, bool bothLose) =
            getResult(room.player1, room.player1Move, room.player2, room.player2Move);
        if (bothLose) {
            _recordLoss(winner);
            _recordLoss(loser);
        } else {
            _recordWin(winner);
            _recordLoss(loser);
        }
        delete rooms[roomName];
    }

    // solhint-disable-next-line code-complexity
    function getResult(
        address player1,
        Move player1Move,
        address player2,
        Move player2Move
    )
        public
        pure
        returns (address winner, address loser, bool bothLose)
    {
        if (player1Move == Move.NONE && player2Move == Move.NONE) {
            return (player1, player2, true);
        }
        if (player1Move == player2Move) {
            return (address(0), address(0), false);
        } else {
            if (player1Move == Move.ROCK) {
                if (player2Move == Move.PAPER) {
                    return (player2, player1, false);
                } else if (player2Move == Move.SCISSORS) {
                    return (player1, player2, false);
                } else {
                    // NONE
                    return (player1, player2, false);
                }
            } else if (player1Move == Move.PAPER) {
                if (player2Move == Move.ROCK) {
                    return (player1, player2, false);
                } else if (player2Move == Move.SCISSORS) {
                    return (player2, player1, false);
                } else {
                    // NONE
                    return (player1, player2, false);
                }
            } else if (player1Move == Move.SCISSORS) {
                if (player2Move == Move.ROCK) {
                    return (player2, player1, false);
                } else if (player2Move == Move.PAPER) {
                    return (player1, player2, false);
                } else {
                    // NONE
                    return (player1, player2, false);
                }
            } else {
                // player1Move == NONE
                return (player2, player1, false);
            }
        }
    }

    function verifyMove(Move move, string memory salt, bytes32 hashedMove) public pure {
        if (hashMove(move, salt) != hashedMove) revert MoveMismatch();
    }

    function hashMove(Move move, string memory salt) public pure returns (bytes32) {
        return keccak256(abi.encode(move, salt));
    }

    function _recordWin(address player) internal {
        Player storage p = players[player];
        p.wins++;
    }

    function _recordLoss(address player) internal {
        Player storage p = players[player];
        p.losses++;
    }
}
