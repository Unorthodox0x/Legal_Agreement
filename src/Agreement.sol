// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IAgreement.sol";
import "./interfaces/IAgreementDeployer.sol";
pragma abicoder v2;

contract Agreement is IAgreement {
    /// @inheritdoc IAgreementImmutables
    address public immutable override factory;
    /// @inheritdoc IAgreementImmutables
    address public immutable override partyA;
    /// @inheritdoc IAgreementImmutables
    address public immutable override partyB;
    /// @inheritdoc IAgreementImmutables
    uint public immutable override expiry; //block.timestamp
    /// @inheritdoc IAgreementImmutables
    uint public override approvedA = 1;
    /// @inheritdoc IAgreementImmutables
    uint public override approvedB = 1;
    /// @inheritdoc IAgreementImmutables
    uint public override verified = 1;

    /// @notice An unordered array of hashes used as keys pointing to messages
    /// ex. messageIndex[0] = _someMessageHash;
    bytes32[] private messageIndex;
    /// @notice mapping to query entire section of agreement
    mapping(uint24 => Message[]) private Sections;

    constructor() {
        (factory, partyA, partyB, expiry) = IAgreementDeployer(msg.sender).parameters();
    }

    ///Modifiers code is copied in all instances where it's used, increasing bytecode size. 
    ///By doing a refractor to the internal function, one can reduce bytecode size 
    /// significantly at the cost of one JUMP.
    function _checkSigner() internal view {
        require(msg.sender == partyA || msg.sender == partyB);
    }

    modifier onlySigner {
        _checkSigner();
        _;
    }

    function _checkStatus() internal view {
        require(verified == 1);
    }

    modifier unSigned {
        _checkStatus();
        _;
    }

    ///@inheritdoc IAgreementActions
    function initialize(MessageParams[] calldata _messages) external override onlySigner unSigned {
        /// @notice gas saver since index starts at 0, no need to calc messageIndex.length each loop
        require(messageIndex.length == 0);
        /// @notice gas saver: len calculated only once outside of loop
        uint len = _messages.length;
        /// @notice gas saver: ++i cheaper addtion method
        for(uint i; i < len; ++i){ //starting from 0
            require(!isMessage(_messages[i]));
            _setMessage(_messages[i], i);
        }
        emit Initialized(address(this));
    }

    ///@inheritdoc IAgreementActions
    function isMessage(MessageParams calldata _message) public view override returns(bool) {
        if(messageIndex.length == 0) return false;
        return (messageIndex[Sections[_message.section][_message.subSection].index] == _message.body);
    }

    ///@inheritdoc IAgreementActions
    function isValid() external view override returns(bool) {
        if(verified == 1) return false;
        if(verified == 2 && block.timestamp > expiry) return false;
        return true;
    }

    ///@inheritdoc IAgreementActions
    ///TODO: Design a multi call to retrieve all sections
    function getSection(uint24 _section) external view override returns(Message[] memory) { 
        return Sections[_section];
    }

    ///@inheritdoc IAgreementActions
    function getMessage(uint24 _section, uint24 _subSection) external view override returns(Message memory) { 
        return Sections[_section][_subSection];
    }
    
    /// @inheritdoc IAgreementActions
    function addMessage(MessageParams calldata _message) external override onlySigner unSigned {
        require(!isMessage(_message));
        uint i = messageIndex.length -1;
        _setMessage(_message, i);
        emit Modified(address(this), msg.sender);
    }

    /**
     * @notice Constructs a Message[] array for more convenient message retrieval
     * if index contains messages, append new messages to array stored at index.
     * @dev Section[1] [empty]
     * @dev Section[1] ==> [ {Message} ]
     * @dev Section[1] ==> [ {Message}, {Message} ]
     */
    function _setMessage(MessageParams calldata _message, uint i) internal {
        messageIndex.push(_message.body);
        Sections[_message.section].push(
            Message({
                section: _message.section,
                subSection: _message.subSection,
                body: _message.body,
                index: i
        }));
    }    

    /// @inheritdoc IAgreementActions
    function updateMessage(MessageParams calldata _message) external override onlySigner unSigned returns(Message memory oldMsg, Message memory newMsg) {
        require(isMessage(_message));
        oldMsg = Sections[_message.section][_message.subSection];
        messageIndex[oldMsg.index] = _message.body; //over write msg @ index
        newMsg = Sections[_message.section][_message.subSection] = Message({
            section: _message.section,
            subSection: _message.subSection,
            body: _message.body,
            index: oldMsg.index
        });
        emit Modified(address(this), msg.sender);
    }

    /// @inheritdoc IAgreementActions
    function remove(MessageParams calldata _message) external override onlySigner unSigned returns(Message memory deletedMsg){
        require(isMessage(_message));
        deletedMsg = Sections[_message.section][_message.subSection];
        delete Sections[_message.section][_message.subSection];
        delete messageIndex[deletedMsg.index];
    }

    /// @inheritdoc IAgreementActions
    ///@notice gas saver: uint less to store than bool
    ///@notice gas saver: costs more to change value from 0
    ///uint(1) == false | uint(2) == true
    function approve(address _signer) external override onlySigner unSigned {
        if(_signer == partyA && approvedA == 1 && approvedB == 1) {
            approvedA = 2;
            emit Approved(address(this), _signer);
        } else if(_signer == partyB && approvedB == 1 && approvedA == 1) {
            approvedB = 2;
            emit Approved(address(this), _signer);
        } else if(_signer == partyA && approvedB == 2 && approvedA == 1) {
            approvedA = 2;
            verified = 2;
            emit Approved(address(this), _signer);
            emit Verified(address(this));
        } else if(_signer == partyB && approvedA == 2 && approvedB == 1) {
            approvedB = 2;
            verified = 2;
            emit Approved(address(this), _signer);
            emit Verified(address(this));
        } else {
            //Revert Case
            //Already Signed by calling party
            revert();
        }
    }
}