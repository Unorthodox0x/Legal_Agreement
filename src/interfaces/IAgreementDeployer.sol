 // SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title An interface for a contract that is capable of deploying Private Agreements
/// @notice A contract that constructs an agreement must implement this to pass arguments to the contract
    //This allows the passage of variables to the contract, externally via importing paras stored in memory

/// @dev This is used to avoid having constructor arguments in the Agreement contract, which results in the init code hash
/// of the Agreement being constant allowing the CREATE2 address of the contract to be cheaply computed on-chain
interface IAgreementDeployer {
    /// @notice Get the parameters to be used in constructing the pool, set transiently during pool creation.
    /// @dev Called by the pool constructor to fetch the parameters of the pool
    /// Returns factory The factory address
    /// Returns partyA The first party of the agreement
    /// Returns partyB The second party of the agreement 
    /// Returns expiry The timestamp when the agreement is no longer valid
    function parameters()
        external
        view
        returns (
            address factory,
            address partyA,
            address partyB,
            uint256 expiry
        );
}
