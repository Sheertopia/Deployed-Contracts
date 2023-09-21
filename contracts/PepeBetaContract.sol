// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@imtbl/imx-contracts/contracts/Mintable.sol";

/// @custom:security-contact https://www.projectlambo.io/contact-us

contract ZeusPepe1155 is ERC1155Burnable, ERC2981, Mintable {
    string public name;
    string public symbol;
    uint256 public mintPriceInWei;
    uint256 public startTokenId;
    uint256 public maxSupply;
    uint96 public royaltyFeesInBips;
    uint256 public mintedAmount;
    uint8 public maxMintAllowedPerWallet;
    bool public isWhitelistApplicable;
    bool public isMintPaused;
    bool public isFreeMintPaused;
    uint256 public totalFreeMinted;
    string public contractURI;
    uint256 public maxSupplyFreeNFTs;
    uint8 public maxFreeMintAllowedPerWallet;
    uint256 private currentWhitelistVersion;
    address public votingContract;
    mapping(address => uint256) private isWhitelisted;
    mapping(address => uint8) public userCurrentNFTBalance;
    mapping(address => uint8) public userCurrentFreeNFTBalance;

    constructor(
        address _owner,
        address _imx,
        address _votingContract
    ) Mintable(_owner, _imx) ERC1155("https://api.projectlambo.com/metadata") {
        name = "Project Lambo: Zeus Pepe Collection";
        symbol = "ZEPE";
        maxSupply = 5000;
        votingContract = _votingContract;
        mintedAmount = 0;
        mintPriceInWei = 10 wei;
        isWhitelistApplicable = false;
        startTokenId = 20001;
        royaltyFeesInBips = 250;
        maxMintAllowedPerWallet = 4;
        maxSupplyFreeNFTs = 420;
        maxFreeMintAllowedPerWallet = 1;
        currentWhitelistVersion = 1; // Not 0. Zero version is given to those who are de-whitelisted
        setRoyaltyInfo(msg.sender, royaltyFeesInBips);
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
                "Not whitelisted"
            );
        }
        _;
    }

    modifier whenFreeMintWhitelisted() {
        if (isWhitelistApplicable) {
            require(
                isWhitelisted[msg.sender] == currentWhitelistVersion,
                "Not whitelisted"
            );
            _;
        }
    }

    /**
     * @dev Modifier to ensure that you can free mint only when allowed by the owners.
     * @notice Reverts with the following error message if free minting has been paused by the owner.
     */
    modifier whenMintNotPaused() {
        require(isMintPaused == false, "Mint is paused.");
        _;
    }

    /**
     * @dev Modifier to ensure that you can free mint only when allowed by the owners.
     * @notice Reverts with the following error message if free minting has been paused by the owner.
     */
    modifier whenFreeMintNotPaused() {
        require(isFreeMintPaused == false, "Free mint is paused.");
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
    function freeMint() external whenFreeMintNotPaused whenFreeMintWhitelisted {
        require(mintedAmount < maxSupply, "Max supply exhausted");

        require(totalFreeMinted < maxSupplyFreeNFTs, "Max supply exhausted");

        require(
            userCurrentFreeNFTBalance[msg.sender] < maxFreeMintAllowedPerWallet,
            "Max wallet limit reached"
        );

        _mint(msg.sender, mintedAmount + startTokenId, 1, "0x00");
        userCurrentFreeNFTBalance[msg.sender]++;
        totalFreeMinted++;
        mintedAmount++;
    }

    function batchMint(
        address[] calldata receivers,
        uint256[] calldata supplyPerReceiver
    ) external onlyOwner {
        require(
            receivers.length == supplyPerReceiver.length,
            "Lengths mismatch"
        );

        uint256 totalNFTsToAirDrop = 0;

        for (uint256 i = 0; i < supplyPerReceiver.length; i++) {
            totalNFTsToAirDrop += supplyPerReceiver[i];
        }

        require(
            mintedAmount + totalNFTsToAirDrop <= maxSupply,
            "Max supply exhausted"
        );

        for (uint256 i = 0; i < receivers.length; i++) {
            uint256[] memory ids = new uint256[](supplyPerReceiver[i]);
            uint256[] memory amounts = new uint256[](supplyPerReceiver[i]);
            uint256 currentIndex = 0;

            for (
                uint256 k = startTokenId + mintedAmount;
                k < startTokenId + mintedAmount + supplyPerReceiver[i];
                k++
            ) {
                ids[currentIndex] = k;
                amounts[currentIndex] = 1;
                currentIndex++;
            }

            _mintBatch(receivers[i], ids, amounts, "0x00");
            mintedAmount = mintedAmount + ids.length;
        }
    }

    /**
     * @dev ImmutableX does not allow for minting on their L2 if this function is not available
     */
    function _mintFor(
        address to,
        uint256 id,
        bytes memory mintingBlob
    ) internal override(Mintable) whenMintWhitelisted whenMintNotPaused {
        // id;
        // mintingBlob;
        // require(mintedAmount < maxSupply, "Max supply exhausted");
        // require(
        //     userCurrentNFTBalance[msg.sender] < maxMintAllowedPerWallet,
        //     "Max wallet limit reached"
        // );
        // _mint(to, mintedAmount + startTokenId, 1, "0x00");
        // mintedAmount++;
        // userCurrentNFTBalance[msg.sender]++;
    }

    function mint() external payable whenMintWhitelisted whenMintNotPaused {
        require(mintedAmount < maxSupply, "Max NFT supply exhausted");
        require(msg.value >= mintPriceInWei, "Insufficient funds sent");
        require(
            userCurrentNFTBalance[msg.sender] < maxMintAllowedPerWallet,
            "Max mint wallet limit reached"
        );

        _mint(msg.sender, mintedAmount + startTokenId, 1, "0x00");
        userCurrentNFTBalance[msg.sender]++;
    }

    function mintAfterBurn(
        address receiver
    ) external onlyOwner returns (uint256) {
        require(mintedAmount < maxSupply, "Max NFT supply exhausted");

        // require(
        //     userCurrentNFTBalance[receiver] < maxMintAllowedPerWallet,
        //     "Max mint wallet limit reached"
        // );

        uint256 tokenID = mintedAmount + startTokenId;
        _mint(receiver, tokenID, 1, "0x00");
        userCurrentNFTBalance[receiver]++;

        return tokenID;
    }

    /**
     * @dev Sets the max supply for free NFTs available.
     * @param newSupply The new supply added by the owner
     */
    function setMaxSupplyFreNFTs(uint256 newSupply) external onlyOwner {
        maxSupplyFreeNFTs = newSupply;
        emit FreeNFTSupplyUpdate(newSupply);
    }

    function updateMaxSupply() external onlyOwner {
        (bool isSuccessful, bytes memory newSupply) = votingContract.call(
            abi.encodeWithSignature("democraticallyFinalizedNewNFTSupply()")
        );

        require(isSuccessful, "FAILED_GETTING_NEW_SUPPLY");
        maxSupply = uint256(bytes32(newSupply));
        emit nftSupplyUpdate(maxSupply);
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
    function addToWhitelist(address[] calldata toWhitelist) external onlyOwner {
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
    ) external onlyOwner {
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
    function toggleWhiteListCheck() external onlyOwner {
        isWhitelistApplicable = !isWhitelistApplicable;
        emit WhitelistCheckUpdate(isWhitelistApplicable);
    }

    /**
     * @dev Sets the new minting price for NFTs in Wei.
     * @param newPriceInWei The new minting price to be set, specified in Wei.
     * @notice Can only be invoked by the contract onwer (deployer)
     * @notice Emit MintPriceUpdate event up on mint price update
     */
    function setMintPriceInWei(uint256 newPriceInWei) external onlyOwner {
        mintPriceInWei = newPriceInWei;
        emit MintPriceUpdate(newPriceInWei);
    }

    /**
     * @param recipient Owner passes an address where they can send their funds
     * @notice Can only be called by the contract owner
     */
    function withdraw(address recipient) public onlyOwner {
        payable(recipient).transfer(address(this).balance);
    }

    /**
     * @dev Pauses the contract functionality ONLY for minting new NFTs and NOTHING else
     * @notice Can only be called by the contract owner (deployer)
     */
    function toggleMintPause() external onlyOwner {
        isMintPaused = !isMintPaused;
        emit ToggleMintPause(isMintPaused);
    }

    /**
     * @dev Pauses the contract functionality ONLY for minting new free NFTs and NOTHING else
     * @notice Can only be called by the contract owner (deployer)
     */
    function toggleFreeMintPause() external onlyOwner {
        isFreeMintPaused = !isFreeMintPaused;
        emit ToggleFreeMintPause(isFreeMintPaused);
    }

    /**
     * @dev Returns the metadata URI for a specific token ID.
     * @param _tokenId The token ID for which the metadata URI is requested.
     * @return The metadata URI corresponding to the given token ID.
     * @notice This function generates the metadata URI using the token ID.
     */
    function uri(
        uint256 _tokenId
    ) public pure override returns (string memory) {
        return
            string(
                string(
                    abi.encodePacked(
                        "https://api.projectlambo.com/metadata",
                        Strings.toString(_tokenId)
                    )
                )
            );
    }

    /**
     * @dev Checks if the contract supports a specific interface.
     * @param interfaceId The interface identifier to check for support.
     * @return True if the contract supports the given interface, otherwise false.
     * @notice This function overrides the supportsInterface function from ERC1155 and ERC2981.
     * @notice Used to determine if the contract implements ERC1155 or ERC2981 interfaces.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC2981) returns (bool) {
        return
            ERC1155.supportsInterface(interfaceId) ||
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
            "Royalty cut expected from 0% to 10%"
        );
        _setDefaultRoyalty(_receiver, _royaltyFeesInBips);
        royaltyFeesInBips = _royaltyFeesInBips;

        emit RoyaltyFeeUpdate(_receiver, _royaltyFeesInBips);
    }

    /**
     * @dev Emitted when the list of addresses 'toWhitelist' are whitelisted
     * @param toWhitelist The list of addresses whitelisted
     */
    event AddtoWhitelist(address[] toWhitelist);

    /**
     * @dev Emitted when the list of addresses 'toWhitelist' are removed from whitelist
     * @param toRemove The list of paddresses removed from whitelist
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
     * @dev Emitted when the owner changes the total quantity of the free NFTs.
     * @param newSupply is sent by the owner
     */
    event FreeNFTSupplyUpdate(uint256 newSupply);

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
    event nftSupplyUpdate(uint256);

    /**
     * @dev Emitted when the royalty fee for a receiver is updated.
     * @param _receiver The address of the receiver for whom the royalty fee is being updated.
     * @param _royaltyFeesInBips The updated royalty fee in basis points (1/100th of a percent).
     */
    event RoyaltyFeeUpdate(address _receiver, uint96 _royaltyFeesInBips);
}
