// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { RPS, Move, Room, Player } from "../src/RPS.sol";

contract RPSTest is Test {
    RPS internal _rps;

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

    function setUp() public {
        _rps = new RPS();
    }

    function test_start() public {
        string memory roomName = "some room";
        address player2 = address(2);
        bytes32 hashedPlayer1Move = _rps.hashMove(Move.PAPER, "salt");
        vm.expectEmit();
        emit RoomStarted(roomName, address(this), player2);
        _rps.start(roomName, player2, hashedPlayer1Move);
        vm.expectRevert(abi.encodeWithSelector(RoomExists.selector));
        _rps.start(roomName, player2, hashedPlayer1Move);
    }

    function testFuzz_start(
        string memory roomName,
        address player1,
        address player2,
        uint8 move,
        string memory salt
    )
        public
    {
        vm.assume(move < 4);
        bytes32 hashedPlayer1Move = _rps.hashMove(Move(move), salt);
        vm.prank(player1);
        vm.expectEmit();
        emit RoomStarted(roomName, player1, player2);
        _rps.start(roomName, player2, hashedPlayer1Move);
        vm.expectRevert(abi.encodeWithSelector(RoomExists.selector));
        _rps.start(roomName, player2, hashedPlayer1Move);
    }
}
