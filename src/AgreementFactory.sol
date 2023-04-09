// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import './interfaces/IAgreementFactory.sol';
import './AgreementDeployer.sol';
import './utils/NoDelegateCall.sol';

contract AgreementFactory is IAgreementFactory, AgreementDeployer, NoDelegateCall {

	/// @inheritdoc IAgreementFactory
    address public override owner;

	/// @inheritdoc IAgreementFactory
    mapping(address => mapping(address => mapping(uint256 => address))) public override getAgreement;

    constructor() {
        owner = msg.sender;
        emit OwnerChanged(address(0), msg.sender);
    }

    /// @inheritdoc IAgreementFactory
    /// @dev requires neither address is null
    /// @dev requires agreement time not passed
    /// @dev requires agreement not already exists
    function createContract(
        address partyA,
        address partyB,
        uint256 expiry //in seconds or blocks
    ) external override noDelegateCall returns (address agreement) {
        require(partyA != address(0) && partyB != address(0));
        require(expiry >= block.timestamp);
        require(getAgreement[partyA][partyB][expiry] == address(0));
        agreement = deploy(address(this), partyA, partyB, expiry);
        getAgreement[partyA][partyB][expiry] = agreement;
        getAgreement[partyB][partyA][expiry] = agreement;
        emit ContractCreated(partyA, partyB, expiry, agreement);
    }

    /// @inheritdoc IAgreementFactory
    function setOwner(address _owner) external override {
        require(msg.sender == owner);
        emit OwnerChanged(owner, _owner);
        owner = _owner;
    }
}