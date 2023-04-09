// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IAgreementEvents {

    /// @notice Emitted when a party modifies the message of the agreement
    event Modified(address agreement, address party);

    /// @notice Emitted exactly once by an agreement when #initialize is first called on the contract
    event Initialized(address agreement);

    /// @notice Emitted exactly twice per agreement, once when agreement is signed 
    ///     by partyA && once when agreement is signed by partyB
    /// @param agreement, the address of the agreement being interacted with
    /// @param party, the address of the party that signed the agreement
    event Approved(address agreement, address party);

    /// @notice Emitted exactly once by an agreement once both parties attributed 
    /// to the agreement have signed the message
    /// @param agreement the address of the agreement 
    event Verified(address agreement);
}