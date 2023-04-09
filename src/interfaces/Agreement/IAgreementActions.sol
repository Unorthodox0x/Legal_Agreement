// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IAgreementActions {

    /// @dev Since Incoming Messages do not have an index a separate struct is required
    /// to structure incoming callddata 
    struct MessageParams {
        uint24 section;     ///@dev Main Section index
        uint24 subSection;  ///@dev Sub Section index
        bytes32 body;       ///@dev Sub Section Message
    }

    /// @notice gas saver: implements struct packing of uint24|uint24
    /// @notice gas saver: storage of body as bytes32 instead of string
    struct Message {
        uint24 section;     ///@dev Main Section index
        uint24 subSection;  ///@dev Sub Section index
        bytes32 body;       ///@dev Sub Section Message
        uint index;         ///@dev location of this Struct in messageIndex array
    }

    /**
     * @notice Takes input message agreed upon partyA and partyB
     * @param _messages an array of Message struct. 
     *  Body of agreement to be agreed up by both parties
     * 
     * @dev strings are expected to be formatted as
     * {section: "Section Title", SubSection: "Sub Section Title": Body: Section's message}
     */
    function initialize(MessageParams[] calldata _messages) external;

    /**
     * @notice checks private messageIndex array for a preexisting message
     * matching the message being added into the agreement
     * @dev prevents wasted gas through duplicate messages
     */
    function isMessage(MessageParams calldata _message) external view returns(bool);

    /**
     * @notice checks the validity of the agreement
     */ 
    function isValid() external view returns(bool);

    /**
     * @notice fetch an entire body section of the messageIndex array
     *  [Sections][1] [{Message}, {Message}, {Message}]
     */
    function getSection(uint24 _section) external view returns(Message[] memory);

    /**
     * @notice fetch a single message that has already been added to the messageIndex array
     */
    function getMessage(
        uint24 _section, 
        uint24 _subSection
    ) external view returns(Message memory);

    
    /**
     * @notice Adds a new message to the agreement
     */
    function addMessage(MessageParams calldata _message) external;

    /**
     * @notice this method can be called at any time before signing to update an 
     *  individual subsection of the agreement this is cheaper than deleting and reuploading
     */
    function updateMessage(MessageParams calldata _message) external returns (Message memory oldMsg, Message memory newMsg);

    /**
     * @notice This method allows for the removal of a subSection of the agreement
     * @param _message an individual Message {section: "", subSection: "", body: ""}
     * @dev delete existing key pointing to message from messageIndex
     * @dev delete Message stored in Section && subSection mappings
     */
    function remove(MessageParams calldata _message) external returns(Message memory deletedMsg);

     /**
     * @notice This function must be called by both partyA and partyB
     *  for this agreement to be valid 
     */
    function approve(address _signer) external;
}