// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

/// @custom:security-contact https://www.projectlambo.io/contact-us

interface IVoting {
    function getFinalizedSupply() external view returns (uint256);
}

contract ZeusPepe721A is ERC721A, ERC2981 {
    uint256 public startTokenId = 20001; // <== Must add here. Needed in 721A
    string private baseTokenURI =
        "https://api.projectlambo.com/metadata/goerli/";
    uint256 public maxSupplyFreeNFTs = 420;
    uint256 public mintPriceInWei = 100 wei;
    uint96 public royaltyFeesInBips = 250; // 2.5%
    uint256 private currentWhitelistVersion = 1;
    uint8 public maxFreeMintAllowedPerWallet = 1;
    bool public isMintPaused = true;
    bool public isFreeMintPaused = true;
    bool public isWhitelistApplicable = true;
    uint256 public totalFreeMinted = 0;

    // Non-hardcoded values below
    address public votingContract;
    address public owner;
    address public beneficiary;
    address public moderator;
    uint256 public maxSupply;
    string public contractURI;

    // Mappings below
    mapping(address => uint256) public isWhitelisted;
    mapping(address => uint8) public userCurrentFreeNFTBalance;

    // Constructor
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        address _votingContract
    ) ERC721A(_name, _symbol) {
        owner = msg.sender;
        beneficiary = msg.sender;
        moderator = msg.sender;
        votingContract = _votingContract;
        maxSupply = _maxSupply;
        setRoyaltyInfo(msg.sender, royaltyFeesInBips);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER_ALLOWED");
        _;
    }

    modifier atleastModerator() {
        require(
            msg.sender == moderator || msg.sender == owner,
            "AT_LEAST_MODERATOR_ALLOWED"
        );
        _;
    }

    /**
     * @dev Modifier to ensure that the caller is whitelisted, if whitelisting is applicable.
     * @notice If whitelisting is enabled, only whitelisted addresses can proceed.
     * @notice Reverts with the following error message if the caller is not whitelisted.
     */
    modifier whenMintWhitelisted() {
        if (isWhitelistApplicable) {
            require(
                isWhitelisted[msg.sender] == currentWhitelistVersion,
                "NOT_WHITELISTED_FOR_MINT"
            );
        }
        _;
    }

    /**
     * @notice when free mint whitelist is not applicable, you cannot free mints
     * @notice if it is applicable, but you are not whitelisted, you cannot mint
     */
    modifier whenFreeMintWhitelisted() {
        require(isWhitelistApplicable, "FREE_MINT_WHITELIST_NOT_APPLICABLE");
        require(
            isWhitelisted[msg.sender] == currentWhitelistVersion,
            "NOT_WHITELISTED_FOR_FREE_MINT"
        );
        _;
    }

    /**
     * @dev Modifier to ensure that you can free mint only when allowed by the owners.
     * @notice Reverts with the following error message if free minting has been paused by the owner.
     */
    modifier whenMintNotPaused() {
        require(isMintPaused == false, "MINT_CURRENTLY_PAUSED");
        _;
    }

    /**
     * @dev Modifier to ensure that you can free mint only when allowed by the owners.
     * @notice Reverts with the following error message if free minting has been paused by the owner.
     */
    modifier whenFreeMintNotPaused() {
        require(isFreeMintPaused == false, "FREE_MINT_CURRENTLY_PAUSED");
        _;
    }

    /**
     * @dev Allows users to mint a new NFT completely for free!
     * @notice the caller must be whitelisted beforehand.
     * @notice the owner must not have paused the free mint.
     * @notice max supply is the free supply + paid NFT supply.
     * @notice Updates the user's free NFT balance and the total minted count.
     * @notice Users can get only 1 free NFT
     */
    function freeMint()
        external
        whenFreeMintNotPaused
        whenFreeMintWhitelisted
        returns (uint256)
    {
        require(ERC721A._totalMinted() < maxSupply, "MAX_SUPPLY_EXHAUSTED");
        require(
            totalFreeMinted < maxSupplyFreeNFTs,
            "MAX_FREE_SUPPLY_EXHAUSTED"
        );
        require(
            userCurrentFreeNFTBalance[msg.sender] < maxFreeMintAllowedPerWallet,
            "MAX_FREE_NFT_WALLET_LIMIT_EXHAUSTED"
        );

        uint256 tokenID = ERC721A._totalMinted() + startTokenId;
        ERC721A._safeMint(msg.sender, 1);
        userCurrentFreeNFTBalance[msg.sender]++;
        totalFreeMinted++;
        return tokenID;
    }

    function airDrop(
        address[] calldata receivers,
        uint256[] calldata supplyPerReceiver
    ) external atleastModerator returns (uint256[] memory) {
        require(
            receivers.length == supplyPerReceiver.length,
            "LENGTHS_MISMATCH"
        );

        uint256 totalNFTsToAirDrop = 0;

        for (uint256 i = 0; i < supplyPerReceiver.length; i++) {
            totalNFTsToAirDrop += supplyPerReceiver[i];
        }

        require(
            ERC721A._totalMinted() + totalNFTsToAirDrop <= maxSupply,
            "MAX_NFT_SUPPLY_EXHAUSTED"
        );

        uint256[] memory tokenIDsToReturn = new uint256[](totalNFTsToAirDrop);

        for (uint256 x = 0; x < totalNFTsToAirDrop; x++) {
            tokenIDsToReturn[x] = ERC721A._totalMinted() + startTokenId + x;
        }

        for (uint256 y = 0; y < receivers.length; y++) {
            ERC721A._safeMint(receivers[y], supplyPerReceiver[y]);
        }

        return tokenIDsToReturn;
    }

    /**
     * @dev Allows users to mint a new NFT by sending the required payment.
     * @notice Users must not exceed the total supply limit, must provide sufficient payment, and must not exceed their wallet's NFT holding limit.
     * @notice Emits a Transfer event upon successful minting.
     * @notice Updates the user's NFT balance and the total minted count.
     * @notice Requires the contract to be not paused and the user to be whitelisted if is whitelist applicable.
     */
    function mint()
        external
        payable
        whenMintWhitelisted
        whenMintNotPaused
        returns (uint256)
    {
        require(ERC721A._totalMinted() < maxSupply, "MAX_NFT_SUPPLY_EXHAUSTED");
        require(msg.value >= mintPriceInWei, "INSUFFICIENT_FUNDS_SENT");

        uint256 tokenID = ERC721A._totalMinted() + startTokenId;
        ERC721A._safeMint(msg.sender, 1);
        return tokenID;
    }

    /**
     * @dev can be called by whitelisted people to re-mint asset
     * on this chain after burning somewhere else
     */
    function reMint(
        address receiver
    ) external atleastModerator returns (uint256) {
        require(ERC721A._totalMinted() < maxSupply, "MAX_NFT_SUPPLY_EXHAUSTED");

        uint256 tokenID = ERC721A._totalMinted() + startTokenId;
        ERC721A._safeMint(receiver, 1);
        return tokenID;
    }

    /**
     * @dev call this to burn a single NFT
     * @notice true value in _burn() call.
     *          True means either you must be the owner
     *          of that asset or approved for it.
     * @dev emits Transfer
     */
    function burn(uint256 tokenID) public {
        ERC721A._burn(tokenID, true);
    }

    /**
     * @dev call it to query the total burned NFTs to date
     * @notice calls the built-in _totalBurned() to get state
     * @notice _totalBurned() is internal
     */
    function totalBurned() external view returns (uint256) {
        return ERC721A._totalBurned();
    }

    function updateModerator(address newModerator) external onlyOwner {
        moderator = newModerator;
    }

    /**
     * @dev Sets the max supply for free NFTs available.
     * @param newSupply The new supply added by the owner
     */
    function setMaxSupplyFreeNFTs(uint256 newSupply) external onlyOwner {
        maxSupplyFreeNFTs = newSupply;
        emit FreeNFTSupplyUpdate(newSupply);
    }

    /**
     * @notice only admins allowed
     * @dev funcion contacts the same-chain voting contract and updates supply
     * @notice voting must have ended (non-zero supply must be returned)
     */
    function updateMaxSupply() external atleastModerator {
        uint256 updatedSupply = IVoting(votingContract).getFinalizedSupply();
        require(
            updatedSupply > ERC721A._totalMinted(),
            "EXPECTED_NEW_SUPPLY_MORE_THAN_MINTED_AMOUNT"
        );
        maxSupply = updatedSupply;
        emit nftSupplyUpdate(maxSupply);
    }

    /**
     * @dev only the current owner can add a new owner
     * @param newOwner is the new owner
     * @notice you need to be careful while passing an address. Only pass good address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    /**
     * @dev voting contract will call this function to get vote weight of the voter
     * @param voter is the address of the person who is invoking vote() methond of Voting
     * @notice it must be external, that's why we cannot use balanceOf for this purpose
     *          as balanceOf is public
        
    */
    function getVoteWeight(address voter) external view returns (uint256) {
        return ERC721A.balanceOf(voter);
    }

    /**
     * @dev Sets the URI for the contract-level metadata.
     * @param _contractURI The new URI for the contract-level metadata.
     */
    function setContractURI(string calldata _contractURI) external onlyOwner {
        contractURI = _contractURI;
    }

    /**
     * @dev Adds the rights of a user to mint new NFTs (only for the whitelisting phase)
     * @dev When whitelisting phase ends, open access to public will be granted
     * @param toWhitelist Is a list of all those people the owner to wishes to allow minting for
     * @notice Can only be called by the contract owner
     * @notice Emit Whitelist event
     */
    function addToWhitelist(
        address[] calldata toWhitelist
    ) external atleastModerator {
        for (uint256 i = 0; i < toWhitelist.length; i++) {
            if (isWhitelisted[toWhitelist[i]] != currentWhitelistVersion) {
                isWhitelisted[toWhitelist[i]] = currentWhitelistVersion;
            }
        }

        emit AddtoWhitelist(toWhitelist);
    }

    /**
     * @dev Revokes the rights of a user to mint new NFTs only when the whitelisting phase is going on
     * @param toRemove Is a list of all those people for whome owner wishes to revoke minting rights
     * @notice Can only be called by the contract owner
     * @notice Emit RemoveFromWhitelist event
     */
    function removeFromWhitelist(
        address[] calldata toRemove
    ) external atleastModerator {
        for (uint256 i = 0; i < toRemove.length; i++) {
            if (isWhitelisted[toRemove[i]] == currentWhitelistVersion) {
                isWhitelisted[toRemove[i]] = 0;
            }
        }

        emit RemoveFromWhitelist(toRemove);
    }

    /**
     * @dev Checks if someone is whitelisted
     * @return true if they are whitelisted
     */
    function isUserWhitelisted(address userToCheck) public view returns (bool) {
        return isWhitelisted[userToCheck] == currentWhitelistVersion;
    }

    /**
     * @dev Removes everyone from the whitelist
     * @notice only the owner can do so
     */
    function clearEntireWhitelist() external onlyOwner {
        currentWhitelistVersion++;
    }

    /**
     * @dev Toggles state to start or stop whitelisting feature for minting new NFTs
     * @notice Can only be called by the contract owner
     * @notice Emit WhitelistCheckUpdate event
     */
    function toggleWhiteListCheck() external atleastModerator {
        isWhitelistApplicable = !isWhitelistApplicable;
        emit WhitelistCheckUpdate(isWhitelistApplicable);
    }

    /**
     * @dev Sets the new minting price for NFTs in Wei.
     * @param newPriceInWei The new minting price to be set, specified in Wei.
     * @notice Can only be invoked by the contract onwer (deployer)
     * @notice Emit MintPriceUpdate event up on mint price update
     */
    function setMintPriceInWei(
        uint256 newPriceInWei
    ) external atleastModerator {
        mintPriceInWei = newPriceInWei;
        emit MintPriceUpdate(newPriceInWei);
    }

    /**
     * @dev function to withdraw crypto funds
     * @notice Can only be called by the contract owner
     */
    function withdraw() external atleastModerator {
        payable(beneficiary).transfer(address(this).balance);
    }

    /**
     * @notice can only be called by the admin
     * @notice make sure to pass a good EOA address ONLY (no contract address)
     * @dev updates the address who can withdraw crypto funds from this contract
     */
    function updateBeneficiary(address _beneficiary) external onlyOwner {
        beneficiary = _beneficiary;
    }

    /**
     * @dev Pauses the contract functionality ONLY for minting new NFTs and NOTHING else
     * @notice Can only be called by the contract owner (deployer)
     */
    function toggleMintPause() external atleastModerator {
        isMintPaused = !isMintPaused;
        emit ToggleMintPause(isMintPaused);
    }

    /**
     * @dev Pauses the contract functionality ONLY for minting new free NFTs and NOTHING else
     * @notice Can only be called by the contract owner (deployer)
     */
    function toggleFreeMintPause() external atleastModerator {
        isFreeMintPaused = !isFreeMintPaused;
        emit ToggleFreeMintPause(isFreeMintPaused);
    }

    /**
     * @dev Sets the value of the base URL for single NFT-level metadata
     * @return baseTokenURI a state variable, having value: "https://api.projectlambo.com/metadata/"
     */
    function _baseURI()
        internal
        view
        virtual
        override(ERC721A)
        returns (string memory)
    {
        return baseTokenURI;
    }

    /**
     * @dev Is a built-in function in ERC-721A, overriden by the team Project Lambo
     * @return startTokenId An unsigned state integer, signaling ERC-721A to start incrementing token IDs from here
     * @notice Is available for internal usage only
     */
    function _startTokenId()
        internal
        view
        virtual
        override(ERC721A)
        returns (uint256)
    {
        return startTokenId;
    }

    /**
     * @dev Checks if the contract supports a specific interface.
     * @param interfaceId The interface identifier to check for support.
     * @return True if the contract supports the given interface, otherwise false.
     * @notice This function overrides the supportsInterface function from ERC721A and ERC2981.
     * @notice It verifies if the interface is supported by either ERC721A or ERC2981 contracts.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721A, ERC2981) returns (bool) {
        return
            ERC721A.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    /**
     * @dev Sets the royalty information for the NFT contract.
     * @param _receiver The address that will receive the royalty payments.
     * @param _royaltyFeesInBips The royalty fees to be collected, expressed in basis points (1/100th of a percent).
     *                           Must be in the range of 0% to 10% (0 to 1000 basis points).
     *                           For example, a value of 500 represents 5% royalty fees.
     * @notice Can only be called by the owner
     * @notice is automatically called during initial contract deployment
     * @notice Emit RoyaltyFeeUpdate event up on royalty fee updated
     */
    function setRoyaltyInfo(
        address _receiver,
        uint96 _royaltyFeesInBips
    ) public onlyOwner {
        require(
            _royaltyFeesInBips >= 0 && _royaltyFeesInBips <= 10 * 100, // 10*100 = 10% as royalty fee is in Bips
            "[ ERROR ]: Royalty cut is expected in the range of 0% to 10%"
        );
        _setDefaultRoyalty(_receiver, _royaltyFeesInBips);
        royaltyFeesInBips = _royaltyFeesInBips;

        emit RoyaltyFeeUpdate(_receiver, _royaltyFeesInBips);
    }

    /**
     * @dev Emitted when the list of addresses 'toWhitelist' are removed from whitelist
     * @param toRemove The list of addresses removed from whitelist
     */
    event RemoveFromWhitelist(address[] toRemove);

    /**
     * @dev Emitted when white list check is updated
     * @param isWhitelistApplicable Current state of white list check
     */
    event WhitelistCheckUpdate(bool isWhitelistApplicable);

    /**
     * @dev Emitted when the mint price of nft is updated
     * @param newPriceInWei New price for nft
     */
    event MintPriceUpdate(uint256 newPriceInWei);

    /**
     * @dev Emitted when the royalty fee for a receiver is updated.
     * @param _receiver The address of the receiver for whom the royalty fee is being updated.
     * @param _royaltyFeesInBips The updated royalty fee in basis points (1/100th of a percent).
     */
    event RoyaltyFeeUpdate(address _receiver, uint96 _royaltyFeesInBips);

    /**
     * @dev Emitted when the owner changes the total quantity of the free NFTs.
     * @param newSupply is sent by the owner
     */
    event FreeNFTSupplyUpdate(uint256 newSupply);

    /**
     * @dev event shows max supply has been decreased or increased
     * @notice it is emitted when voting is done, owner calls voting contract to get new supply and set new supply
     */
    event nftSupplyUpdate(uint256);

    /**
     * @dev Emitted when the list of addresses 'toWhitelist' are whitelisted
     * @param toWhitelist The list of addresses whitelisted
     */
    event AddtoWhitelist(address[] toWhitelist);

    /**
     * @dev Emitted when the owner resumes or stops minting of new NFTs.
     * @param isPaused is true if owner stops minting
     */
    event ToggleMintPause(bool isPaused);

    /**
     * @dev Emitted when the owner resumes or stops minting of new free NFTs.
     * @param isPaused is true if owner stops free minting
     */
    event ToggleFreeMintPause(bool isPaused);
}

