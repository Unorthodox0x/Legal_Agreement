// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./interfaces/IAgreement.sol";
import "./interfaces/IAgreementDeployer.sol";
pragma abicoder v2;


//TODO: FACTORY CONTRACT SHOULD BE ABLE TO MANAGE MESSAGE INITIALIZATION SO NO PARTY
//HAS TO RE APPEND MESSAGE LATER
//THIS MESSAGE CAN BE USED TO SALT CONTRACT??

///METHODS TO ADD
/// GET WHOLE MESSAGE
/// GET SECTION COUNT
/// GET MESSAGE COUNT getAgreementLength() external view returns(uint);

//ADD CUSTOM ERRORS TO REDUCE GAS
//TEST CUSTOM ERRORS

//ADD MULTICALL METHODS
// add multiple messages in single call
// update multiple messages in single call
// remove multiple messages in single call

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
    uint public override pauseA = 1;
    /// @inheritdoc IAgreementImmutables
    uint public override approvedB = 1;
    /// @inheritdoc IAgreementImmutables
    uint public override pauseB = 1;
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

    function _checkVerification() internal view {
        require(verified == 1);
    }

    modifier unSigned {
        _checkVerification();
        _;
    }

    function _checkPaused() internal view {
        require(pauseA == 1 && pauseB == 1);
    }

    modifier unPaused {
        _checkPaused();
        _;
    }

    ///@inheritdoc IAgreementActions
    function isValid() external view override returns(bool) {
        if(verified == 1) return false;
        if(verified == 2 && block.timestamp > expiry) return false;
        return true;
    }

    ///@inheritdoc IAgreementActions
    function isPaused() external view override returns(bool) {
        return pauseA == 2 || pauseB == 2;
    }

    ///TODO: Design a multi call to retrieve all sections
    ///@inheritdoc IAgreementActions
    function getSection(uint24 _section) external view override returns(Message[] memory) { 
        return Sections[_section];
    }

    ///@inheritdoc IAgreementActions
    function getMessage(uint24 _section, uint24 _subSection) external view override returns(Message memory) { 
        return Sections[_section][_subSection];
    }

    ///@inheritdoc IAgreementActions
    ///@dev called during initialize
    ///@dev called during addMessage, contract calls post initialize
    function isMessage(MessageParams calldata _message) public view override returns(bool) {
        if(messageIndex.length == 0) return false;

        //@notice gas save: Cache SLoad value to prevent multiple Sloads 
        Message[] memory SectionArr = Sections[_message.section];
        uint len = SectionArr.length;
        
        // console.log("%d", len);
        // console.log("%d", _message.subSection);
        // console.log(len == _message.subSection); //len == 1, _message.subSection == 1
        // console.log(len == 0);
        // console.log(len  < _message.subSection);

        /// MAPPINGS ARE CREATED WITH ALL VALUES SET IN MEMORY
        /// Sections[_message.section] EXISTS, BUT IF THAT ARRAY DOES NOT HAVE AN ELEMENT AT Section[section][subSection]
        /// an out of index error occurs
        if(len == 0 || len - 1  < _message.subSection) return false; 
        if(messageIndex.length - 1 < SectionArr[_message.subSection].index) return false;

        return messageIndex[SectionArr[_message.subSection].index] == _message.body;
    }

    ///@inheritdoc IAgreementActions
    function initialize(MessageParams[] calldata _messages) external override onlySigner unSigned {
        require(messageIndex.length == 0);

        /// @notice gas saver: len calculated once outside of loop
        uint len = _messages.length;
        /// @notice gas saver: ++i cheaper addition method
        for(uint i; i < len; ++i) {
            require(!isMessage(_messages[i]));
            /**
             * init flow 
             * messageIndex.length == 0
             * messageIndex.push(_msg)
             * messageIndex.length == 1, msg Index == 0
             * _setMsg index == 0
             */
            _setMessage(_messages[i]);
            messageIndex.push(_messages[i].body);
        }

        emit Initialized(address(this));
    }
    
    /// @inheritdoc IAgreementActions
    /// @dev callable after initialize to add single message
    function addMessage(MessageParams calldata _message) external override onlySigner unPaused unSigned {
        require(messageIndex.length != 0);
        require(!isMessage(_message));
        
        /**
         * add flow example
         * messageIndex.length == 9, 9 msgs stored, last msg index == 8 
         * messageIndex.push(_newMsg), 
         * messageIndex.length == 10, newMsg index == 9
         * _setMsg index == 9
         */        
        _setMessage(_message);
        messageIndex.push(_message.body);
        emit Modified(address(this), msg.sender);
    }

    /**
     * @notice Constructs a Message[] array for more convenient message retrieval
     * if index contains messages, append new messages to array stored at index.
     * @dev Section[1] [empty]
     * @dev Section[1] ==> [ {Message} ]
     * @dev Section[1] ==> [ {Message}, {Message} ]
     * @dev initilaztion process - messageIndex.push() starts from 0， so _message.index == messageIndex.length - 1
     */
    function _setMessage(MessageParams calldata _message) internal {
        Sections[_message.section].push(
            Message({
                section: _message.section,
                subSection: _message.subSection,
                body: _message.body,
                index: messageIndex.length
        }));
    }

    /// @inheritdoc IAgreementActions
    function updateMessage(MessageParams calldata _message) external override onlySigner unPaused unSigned returns(Message memory oldMsg) {
        uint len = Sections[_message.section].length;
        require(len != 0 && len >= uint(_message.subSection));

        oldMsg = Sections[_message.section][_message.subSection];             
        messageIndex[oldMsg.index] = _message.body; //overwrite msg @ index
        Sections[_message.section][_message.subSection] = Message({
            section: _message.section,
            subSection: _message.subSection,
            body: _message.body,
            index: oldMsg.index
        });

        emit Modified(address(this), msg.sender);
    }

    /// @inheritdoc IAgreementActions
    function remove(MessageParams calldata _message) external override onlySigner unPaused unSigned returns(Message memory deletedMsg){
        require(isMessage(_message));
        
        deletedMsg = Sections[_message.section][_message.subSection];
        delete Sections[_message.section][_message.subSection];
        delete messageIndex[deletedMsg.index];
    }

    /**
     * @notice pauses all modification to the agreement message
     * @notice This preparation step comes before the signing of the agreement
     * @dev without this functionality there would be no way for partyA or partyB to be sure the message
     *      they are signing has not been modified.
     */
    function manageReviewStatus() external override onlySigner unSigned {
        require(messageIndex.length != 0); //cannot pause empty
        if(msg.sender == partyA && pauseA == 1) {
            pauseA = 2;
            emit Paused(address(this));
        } else if(msg.sender == partyA && pauseA == 2) { 
            pauseA = 1;
            if(pauseA == 1 && pauseB == 1) { 
                emit UnPaused(address(this));
            }
        } else if(msg.sender == partyB && pauseB == 1) {
            pauseB = 2;
            emit Paused(address(this));
        }  else if(msg.sender == partyB && pauseB == 2) { 
            pauseB = 1;
            if(pauseA == 1 && pauseB == 1) { 
                emit UnPaused(address(this));
            }
        }
    }

    /// @inheritdoc IAgreementActions
    ///@notice gas saver: uint less to store than bool
    ///@notice gas saver: costs more to change value from 0
    ///uint(1) == false | uint(2) == true
    function approve() external override onlySigner unSigned {        
        require(messageIndex.length != 0); //cannot approve empty
        if(msg.sender == partyA && approvedA == 1 && approvedB == 1) {
            approvedA = 2;
            emit Approved(address(this), msg.sender);
        } else if(msg.sender == partyB && approvedB == 1 && approvedA == 1) {
            approvedB = 2;
            emit Approved(address(this), msg.sender);
        } else if(msg.sender == partyA && approvedB == 2 && approvedA == 1) {
            approvedA = 2;
            verified = 2;
            emit Approved(address(this), msg.sender);
            emit Verified(address(this));
        } else if(msg.sender == partyB && approvedA == 2 && approvedB == 1) {
            approvedB = 2;
            verified = 2;
            emit Approved(address(this), msg.sender);
            emit Verified(address(this));
        } else {
            //Revert Case
            //Already Signed by calling party
            revert();
        }
    }
}