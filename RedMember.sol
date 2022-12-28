// SPDX-Lecense-Identifier: Unlicensed
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "hardhat/console.sol";
contract RedMember is
    ERC721,
    ERC721URIStorage,
    Pausable,
    Ownable,
    AccessControl,
    ERC721Burnable
{
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Global counters
    using Strings for uint256;
    using Counters for Counters.Counter;
    // Counters.Counter private _tokenIds;
    Counters.Counter private _tokenIdCounter;
    address public defaultPassOwnerAddress;

    // events
    event CreatedEvent(
        address owner,
        uint256 passId,
        string passSignature,
        uint8 passTypeCode
    );

    uint8 public PASS_TYPE_EGG = 0; 
    uint8 public PASS_TYPE_EARLYBIRD = 1; 
    uint8 public PASS_TYPE_WHITELISTED = 2; 
    uint8 public PASS_TYPE_REDLISTED = 3; 

    mapping(uint8 => uint256) public passTypeCreatedCounter; // shows currently minted pass type amounts
    mapping(uint8 => uint256) public passTypeLimits; // shows currently enforced pass type limits
    mapping(uint8 => uint256) public passTypesLimitChangeable; // shows if pass type limit be edited by admin
    mapping(uint8 => string) public passTypeNames; // map passtype code to name

    string private BASE_URI = "https://app.redcurry.co/passes/token/";

    struct Pass {
        string passId;
        uint256 tokenId;
        // The genetic code is packed into a hash, the format is
        // a secret! A pass's passSignature can never change - authentisity.
        string passSignature;
        // The timestamp from the block when this pass came into existence.
        uint64 createdAt;
        uint8 passTypeCode;
        string passTypeName;
        string title;
        string description;
        string imgUrl;
    }

    /// @dev A map containing the Pass struct for all Passes in existence.
    mapping(uint256 => Pass) public tokenIdToPass;

    /// @dev A map containing all minted tokens mapped to the current owner.
    mapping(uint256 => address) public tokenIdToOwner;

    /// @dev A mapping from owner address to count of tokens that address owns.
    mapping(address => uint256) ownershipTokenCount;

    mapping(string => uint256) passIdToTokenId;

    constructor() ERC721("Redcurry Membership", "REDM") {
        // Contract creator gets all roles.
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(UPDATER_ROLE, msg.sender);
        defaultPassOwnerAddress = msg.sender;

        passTypeLimits[PASS_TYPE_EGG] = 300;
        passTypeLimits[PASS_TYPE_EARLYBIRD] = 700;
        passTypeLimits[PASS_TYPE_WHITELISTED] = 300;
        passTypeLimits[PASS_TYPE_REDLISTED] = 100;

        // 1 = can be edited
        // 0 = cannot be edited later
        passTypesLimitChangeable[PASS_TYPE_EGG] = 0;
        passTypesLimitChangeable[PASS_TYPE_EARLYBIRD] = 0;
        passTypesLimitChangeable[PASS_TYPE_WHITELISTED] = 1;
        passTypesLimitChangeable[PASS_TYPE_REDLISTED] = 1;

        passTypeNames[PASS_TYPE_EGG] = "EGG";
        passTypeNames[PASS_TYPE_EARLYBIRD] = "EARLYBIRD";
        passTypeNames[PASS_TYPE_WHITELISTED] = "WHITELISTED";
        passTypeNames[PASS_TYPE_REDLISTED] = "REDLISTED";

    }



    /// @dev Method that creates a new pass and stores it.
    /// @param _title The pass's title.
    /// @param _description The pass's description.
    /// @param _typeCode The pass's type code(Enum representation in number).
    /// @param _owner The inital owner of this pass, must be non-zero.
    /// @param _imgUrl Link to image URL (static, public).
    /// @param _passSignature The pass's passSignature code (verifiable validity signature hash).
    function createPass(
        string memory passId,
        string memory _title,
        string memory _description,
        uint8 _typeCode,
        address _owner,
        string memory _imgUrl,
        string memory _passSignature
    ) external onlyRole(MINTER_ROLE) whenNotPaused returns (uint256) {
        address membershipOwner = _owner;
        if (membershipOwner == address(0)) {
            membershipOwner = defaultPassOwnerAddress;
        }

        string memory passTypeName = passTypeNames[_typeCode];

        require(passTypeCreatedCounter[_typeCode] <= passTypeLimits[_typeCode]);
        passTypeCreatedCounter[_typeCode]++;

        _tokenIdCounter.increment(); // start with 1
        uint256 tokenId = _tokenIdCounter.current();

        Pass memory _pass = Pass({
            passId: passId,
            tokenId: tokenId,
            title: _title,
            description: _description,
            passSignature: _passSignature,
            createdAt: uint64(block.timestamp),
            passTypeCode: _typeCode,
            passTypeName: passTypeName,
            imgUrl: _imgUrl
        });

        tokenIdToPass[tokenId] = _pass;
        passIdToTokenId[passId] = tokenId;
        _safeMint(_owner, tokenId);

        // emit the event
        emit CreatedEvent(_owner, tokenId, _pass.passSignature, _typeCode);

        return tokenId;
    }

    // Standard requirement to show NFT metadata on OpenSea and other sites.
    // standard: https://docs.opensea.io/docs/metadata-standards
    /*
    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        Pass memory pass = tokenIdToPass[tokenId];

        bool 
        if(pass.passTypeCode === 2 || pass.passTypeCode === 3) 
 
        struct tokenMetadata {
            name: pass.title + " #" + pass.passId;
            external_url: "https://app.redcurry.co/membership/passes/" + tokenId.toString();
            description: pass.description;
            image: pass.imgUrl;
            attributes: [
                {
                    trait_type: "Badge type";
                    value: pass.title
                },
                {
                    trait_type: "Edition";
                    value: "Limited"
                },
            ]
        }

        bytes memory dataURI = abi.encodePacked(tokenMetadata.toString());
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(dataURI)
                )
            );
    }
*/
    function getTokenId(string memory passId) view public returns (uint256){
        return passIdToTokenId[passId];
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        BASE_URI = baseURI;
    }

    function _baseURI() internal view override returns (string memory){
        return BASE_URI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
        onlyRole(BURNER_ROLE)
        whenNotPaused
        
    {
        require(isTokenOwner(msg.sender, tokenId));
        super._burn(tokenId); 
    }

    // ****************************
    // ****** ACCESS CONTROL ******
    // ****************************
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function grantAnyRole(bytes32 role, address receivingAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _grantRole(role, receivingAddress); // (grantRole is an override of _grantRole and checks for admin role. Avoid 2xChecks, call direct.)
    }

    function revokeAnyRole(bytes32 role, address receivingAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _revokeRole(role, receivingAddress);
    }

    function setDefaultPassOwnerAddress(address _address)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        defaultPassOwnerAddress = _address;
    }

    // ****************************
    // ****** LIMIT & SUPPLY ******
    // ****************************
    function changePassLimit(uint256 _newLimit, uint8 _typeCode)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {

        require(
            _newLimit != passTypeLimits[_typeCode],
            "New limit cannot be same as old."
        );

        require(
            passTypesLimitChangeable[_typeCode] == 1,
            "This pass type limits cannot be changed."
        );

        uint256 passesCreated = passTypeCreatedCounter[_typeCode];
        require(_newLimit > passesCreated, "New limit must be bigger than types already minted.");

        passTypeLimits[_typeCode] = _newLimit;
    }

    // *************************
    // ****** BOILERPLATE ******
    // *************************
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function isTokenOwner(address sender, uint256 tokenId) internal view returns (bool){
        address owner = ownerOf(tokenId);
        return sender == owner;
    }
}
