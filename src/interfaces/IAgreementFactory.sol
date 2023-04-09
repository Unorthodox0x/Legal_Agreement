// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


/// @title The interface for Contract Factory
/// @notice This factory contract facilitates creation of agreement contracts between parties and control over the protocol fees
interface IAgreementFactory {

    /// @notice Emitted when the owner of the factory is changed
    /// @param oldOwner The owner before the owner was changed
    /// @param newOwner The owner after the owner was changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when an agreement is created
    /// @param partyA The first party of the agreement by address sort order
    /// @param partyB The second party of the agreement by address sort order
    /// @param expiry The validity window of the agreement
    /// @param agreement The address of the created agreement
    event ContractCreated(
        address indexed partyA,
        address indexed partyB,
        uint256 indexed expiry,
        address agreement
    );

    /// @notice Returns the current owner of the factory
    /// @dev Can be changed by the current owner via setOwner
    /// @return The address of the factory owner
    function owner() external view returns (address);

    /// @notice Returns the agreement address for a given agreement and tokenId,
    /// @dev partyA and partyB may be passed in either partyA/partyB or partyB/partyA order
    /// @param partyA The address of either partyA or partyB
    /// @param partyB The address of the other party
    /// @param expiry The validity window of the agreement
    /// @return agreement The agreement address
    function getAgreement(
        address partyA,
        address partyB,
        uint256 expiry
    ) external view returns (address agreement);

    /// @notice Creates a contract for the given two parties
    /// @param partyA One of the two parties participating in the agreement
    /// @param partyB The other of the two parties in the agreement
    /// @dev partyA and partyB may be passed in either order: partyA/partyB or partyB/partyA.
    /// @return agreement The address of the newly created agreement
    function createContract(
        address partyA,
        address partyB,
        uint256 expiry //in seconds
    ) external returns (address agreement);

    /// @notice Updates the owner of the factory
    /// @dev Must be called by the current owner
    /// @param _owner The new owner of the factory
    function setOwner(address _owner) external;
}
