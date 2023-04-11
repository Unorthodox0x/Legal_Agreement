// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Agreement state that never changes
/// @notice These parameters are fixed for a Contract forever, i.e., the methods will always return the same values
interface IAgreementImmutables {

    /// @notice The contract that deployed the contact, which must adhere to the IAgreementFactory interface
    /// @return The contract address
    function factory() external view returns (address);

    /// @notice The first of the two parties of the agreement, sorted by address
    /// @return partyA wallet address
    function partyA() external view returns (address);

    /// @notice The second of the two parties of the agreement, sorted by address
    /// @return partyB wallet address
    function partyB() external view returns (address);

    /// @notice The time when the contract becomes invalid;
    /// @return The expiry timestamp
    function expiry() external view returns (uint256);

    /// @dev original signature of partyA
    /// @notice Has the agreement been signed by partyA;
    function approvedA() external view returns (uint256);

    /// @dev original signature of partyB
    /// @notice Has the agreement been signed by partyB;
    function approvedB() external view returns (uint256);

    /// @notice the status of partyA's contract review request
    /// @dev if == 2, contract is paused
    function pauseA() external view returns (uint256);

    /// @notice the status of partyB's contract review request
    /// @dev if == 2, contract is paused
    function pauseB() external view returns (uint256);

    /// @notice Has the agreement been signed by both parties;
    ///@dev approvedA && approvedB
    function verified() external view returns (uint256);
}
