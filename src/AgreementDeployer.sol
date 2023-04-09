// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import './interfaces/IAgreementDeployer.sol';
import "./Agreement.sol";

contract AgreementDeployer is IAgreementDeployer {
	struct Parameters {
        address factory;
        address partyA;
        address partyB;
        uint256 expiry;
    }

    /// @inheritdoc IAgreementDeployer
    Parameters public override parameters;

    /// @dev Deploys an Agreement with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Agreement factory
    /// @param partyA The first token of the contract by address sort order
    /// @param partyB The second token of the contract by address sort order
    /// @param expiry timestamp when agreement expiry
    function deploy(
        address factory,
        address partyA,
        address partyB,
        uint256 expiry
    ) internal returns (address agreement) {
        parameters = Parameters({ factory: factory, partyA: partyA, partyB: partyB, expiry: expiry });
        agreement = address(new Agreement{salt: keccak256(abi.encode(partyA, partyB, expiry))}());
        delete parameters;
    }
}