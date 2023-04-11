// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {Agreement} from  "src/Agreement.sol";
import {IAgreementActions} from "src/interfaces/Agreement/IAgreementActions.sol";
import {AgreementFactory} from "src/AgreementFactory.sol";
import {IAgreementFactory} from "src/interfaces/IAgreementFactory.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


/** 
 * Run this Test
 * $ forge test --match-path test/ArrayManipulation.t.sol
 */
contract ArrayManipulationTest is Test {
    
    AgreementFactory public factoryContract;
    Agreement public newAgreement;

    address public owner; //0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 expected
    address public Alice;
    address public Bob;
    address public Charles;
    uint expiry;
    
    bytes32[] public messageIndex;
    IAgreementActions.MessageParams[] public inputMessage;

    /**
     * Testing of initializing may require separate scenarioes and thus
     *  separate test files with their own setUp context
     */
    function setUp() public {
        expiry = block.timestamp + 2000; //set static for uniform testing

        owner = msg.sender;
        Alice = makeAddr("Alice");
        Bob = makeAddr("Bob");
        Charles = makeAddr("Charles");
        
        //guarantees factory owner address
        vm.prank(owner);
        factoryContract = new AgreementFactory();
        address _agreement = factoryContract.createContract(Alice, Bob, expiry);
        newAgreement = Agreement(_agreement);

        createMessage();
        initAgreement();
    }

    function initAgreement() internal {
        IAgreementActions.MessageParams[] memory _input = inputMessage;
        vm.prank(Alice);

        //Store message
        newAgreement.initialize(_input);
    }

    /**
     * [util]
     * @notice hash the message offline before storage on contract to reduce contract storage
     *  and gas prices
     * @notice online hasing is computationally expensive, best to do offline;
     */
    function hashMessage(string memory _body) internal pure returns (bytes32) { 
        return keccak256(abi.encodePacked(_body));
    }

    /**
     *  Current solidity verion <=0.8.13 do not support initialization of 
     *      arrays of structs.
     * 
     *  Instead initialize an empty MessageParams array in Foundry State memory, 
     *    and push this message struct to smart contract to update state.
     *    in contract memory.  
     */
    function createMessage() public {
        for(uint24 i; i < 5; ++i){
            for(uint24 j; j < 2; ++j){
                bytes32 _msgHash = hashMessage( string.concat("This is message ", Strings.toString(i), ".", Strings.toString(j)) );
                //Push message to inputMessage arary to intialize message to be sent to smart contract
                messageIndex.push(_msgHash);
                inputMessage.push(
                    IAgreementActions.MessageParams({
                        section: i,
                        subSection: j,
                        //Hash message before storage
                        body: _msgHash
                    })
                );
            }
        }
    }

    /**
     * This should allow a new message to be added to Sections array, 
     *  and confirm that the bytes32 at messageIndex[msg.index] matches
     * 
     * add msg flow
     *   messageIndex.length == 9, 9 msgs stored, last msg index == 8 
     *   messageIndex.push(_newMsg), 
     *   messageIndex.length == 10, newMsg index == 9
     *   _setMsg index == 9
     */
    function test_AddMessage(uint24 _section, uint24 _subSection) public {
        vm.assume(_section > 5);
        vm.assume(_subSection == 0);

        bytes32 _msgHash = hashMessage( string.concat("This is message ", Strings.toString(_section), ".", Strings.toString(_subSection)));
        messageIndex.push(_msgHash);
        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section: _section,
            subSection: _subSection,
            body: _msgHash
        });

        vm.prank(Alice);
        //add
        newAgreement.addMessage(newMsg);
        //retrive from contract storage
        IAgreementActions.Message memory _msg = newAgreement.getMessage(_section, _subSection);
        
        //TESTS
        assertEq(_msg.section, newMsg.section);
        assertEq(_msg.subSection, newMsg.subSection);
        assertEq(_msg.body, newMsg.body);
        assertEq(newMsg.body, messageIndex[_msg.index]);
    }

    /**
     * expect - This should fail if message at Sections[section][subSection] is not empty
     */
    function test_RejectAddDuplicate(uint24 _section, uint24 _subSection) public {
        //assure message has been added
        vm.assume(_section < 5);
        vm.assume(_subSection < 2);

        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section:_section, 
            subSection: _subSection, 
            body: hashMessage( string.concat("This is message ", Strings.toString(_section), ".", Strings.toString(_subSection)) )
        });
        
        vm.prank(Alice);
        vm.expectRevert(bytes(""));
        newAgreement.addMessage(newMsg);
    }

    /**
     * expect - This should fail if msg.sender is neither Alice or Bob 
     */
    function test_Reject3rdPartyAdd(uint24 _section, uint24 _subSection) public {
        vm.assume(_section > 5);
        vm.assume(_subSection == 0);

        messageIndex.push(hashMessage( string.concat("This is message ", Strings.toString(_section), ".", Strings.toString(_subSection))));
        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section: _section,
            subSection: _subSection,
            body: hashMessage(string.concat("This is message ", Strings.toString(_section), ".",  Strings.toString(_subSection)))
        });

        vm.prank(Charles);
        vm.expectRevert(bytes(""));
        newAgreement.addMessage(newMsg);
    }

    /**
     * expect - either party A or partyB should be able to modify a message
     * This tests update of 1st message only;
     * 
     *  1. ADD MESSAGE
     *  2. GET MESSAGE FROM CONTRACT, PLACE IN LOCAL FOUNDRY STORAGE
     *  3. UPDATE MESSAGE IN CONTRACT
     *  4. COMPARE CONTRACT && FOUNDRY VALUES
     */
    function test_UpdateMessage(uint24 _section, uint24 _subSection) public {
        //assure message has been added
        vm.assume(_section < 5);
        vm.assume(_subSection < 2);

        //fetch message before update
        IAgreementActions.Message memory _oldMsg = newAgreement.getMessage(_section, _subSection);

        //Create new message to update existing msg in messageIndex
        bytes32 _updatedMsgHash = hashMessage( string.concat("This is updated message ", Strings.toString(_section), ".", Strings.toString(_subSection)));
        
        messageIndex[_oldMsg.index] = _updatedMsgHash;

        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section: _oldMsg.section, //puts new message at old message index
            subSection: _oldMsg.subSection, //puts new message at old message index
            body: _updatedMsgHash //message to update
        });

        vm.startPrank(Alice);
        newAgreement.updateMessage(newMsg);
        IAgreementActions.Message memory _updatedMsg = newAgreement.getMessage(_section, _subSection);

        //new message matches msg used to update
        assertEq(_oldMsg.section, _updatedMsg.section);
        assertEq(_oldMsg.subSection, _updatedMsg.subSection);
        assertFalse(_oldMsg.body == _updatedMsg.body);
        //index unchanged
        assertEq(_oldMsg.index, _updatedMsg.index);
        //Message changed
        //new message in mapping not same as old
        assertFalse(_updatedMsgHash == _oldMsg.body);
        //new message in messageIndex not same as old
        assertFalse(messageIndex[_oldMsg.index] == _oldMsg.body);
        assertEq(messageIndex[_oldMsg.index], _updatedMsgHash);
    }

    /**
     * exepct - This will fail if a user attempts to update a message that does not yet exist
     * @dev message request Sections[_section][_subSection] where 
     *      _subSection > Sections[_section].length resultse in Out of bounds reversion
     */
    function test_RejectUpdateMessage(uint24 _section, uint24 _subSection) public {
        vm.assume(_section > 6);
        vm.assume(_subSection == 0);

        //Create new message to update existing msg in messageIndex
        bytes32 _updatedMsgHash = hashMessage( string.concat("This is updated message ", Strings.toString(_section), ".", Strings.toString(0)));

        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section: _section, //puts new message at old message index
            subSection: 0, //puts new message at old message index
            body: _updatedMsgHash //message to update
        });

        vm.startPrank(Alice);
        vm.expectRevert(bytes(""));
        newAgreement.updateMessage(newMsg);
    }

    /**
     * expect- this will fail if a 3rd party tries to update any messages in the agreement
     */
    function test_Reject3rdPartyUpdate(uint24 _section, uint24 _subSection) public {
        //assure message has been added
        vm.assume(_section < 5);
        vm.assume(_subSection < 2);

        //fetch message before update
        IAgreementActions.Message memory _oldMsg = newAgreement.getMessage(_section, _subSection);

        //Create new message to update existing msg in messageIndex
        bytes32 _updatedMsgHash = hashMessage( string.concat("This is updated message ", Strings.toString(_section), ".", Strings.toString(_subSection)));
        IAgreementActions.MessageParams memory newMsg = IAgreementActions.MessageParams({
            section: _oldMsg.section, //puts new message at old message index
            subSection: _oldMsg.subSection, //puts new message at old message index
            body: _updatedMsgHash //message to update
        });

        vm.startPrank(Charles);
        vm.expectRevert(bytes(""));
        newAgreement.updateMessage(newMsg);
    }

    /**
     * expect - partyA || partyB can remove a message after initialized
     */
    function test_RemoveMessage(uint24 _section, uint24 _subSection) public {
        //test remove any message added during initialization
        vm.assume(_section < 5);
        vm.assume (_subSection <= 1);

        IAgreementActions.MessageParams memory _toRemove = IAgreementActions.MessageParams({
            section: _section, //puts new message at old message index
            subSection: _subSection, //puts new message at old message index
            body: hashMessage( string.concat("This is message ", Strings.toString(_section), ".", Strings.toString(_subSection)))
        });

        //REMOVE
        vm.startPrank(Alice);
        IAgreementActions.Message memory _deletedMsg = newAgreement.remove(_toRemove);

        //make same modification to foundry stored messageIndex as made to Contract stored messageIndex
        delete messageIndex[_deletedMsg.index];

        //Fetch removed message
        IAgreementActions.Message memory _removed = newAgreement.getMessage(_deletedMsg.section, _deletedMsg.subSection);
        //TESTS
        assertEq(_removed.section, 0);
        assertEq(_removed.subSection, 0);
        assertEq(_removed.body, 0);
        
        //A better way to test this would be to design a method to retrive contract state
        //and confirm deletion
        assertEq(messageIndex[_deletedMsg.index], 0);
    }

    /**
     * AFTER MESSAGE REMOVAL, HOW WILL OTHER FUNCTIONALITY BE AFFECTED?
     */

    /**
     * expect - This should fail if msg.sender is neither Alice or Bob 
     */
    function test_Reject3rdPartyRemove(uint24 _section, uint24 _subSection) public {
        //test remove any message added during initialization
        vm.assume(_section < 5);
        vm.assume (_subSection <= 1);

        IAgreementActions.MessageParams memory _toRemove = IAgreementActions.MessageParams({
            section: _section, //puts new message at old message index
            subSection: _subSection, //puts new message at old message index
            body: hashMessage( string.concat("This is message ", Strings.toString(_section), ".", Strings.toString(_subSection)))
        });

        //ATTEMPT REMOVE
        vm.startPrank(Charles);
        vm.expectRevert(bytes(""));
        newAgreement.remove(_toRemove);
    }
}
