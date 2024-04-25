// This is a template contract
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract LamboWeapons is ERC1155, ERC1155Pausable, Ownable, ERC1155Supply {
    using Strings for uint256;
    address public server;
    string public name;
    string public symbol;
    mapping(uint256 => string) public addons;
    string public baseUrl;

    constructor(address _server) Ownable(msg.sender) ERC1155("") {
        server = _server;
        name = "Lambo:Weapons";
        symbol = "LWPN";
        baseUrl = "https://lime-unacceptable-swordtail-798.mypinata.cloud/ipfs/QmNicQyq3DtvMbjUppN7MywYX45M9TabbYzctNXK38PPpZ/";
    }

    modifier _serverOrOwner() {
        require(msg.sender == server || msg.sender == owner(), "ACCESS DENIED");
        _;
    }

    modifier _validAddress(address _addr) {
        require(_addr != address(0x00), "INVALID ADDRESS");
        _;
    }

    modifier _validString(string memory _str) {
        bytes memory stringData = bytes(_str);
        require(stringData.length != 0, "INVALID TEXT DATA");
        _;
    }

    modifier _requireNFTNotExist(uint256 _tokenId) {
        bytes memory nftData = bytes(addons[_tokenId]);
        require(nftData.length == 0, "NFT ALREADY Exist");
        _;
    }

    modifier _requireNFTExist(uint256 _tokenId) {
        bytes memory nftData = bytes(addons[_tokenId]);
        require(nftData.length != 0, "NFT NOT Exist");
        _;
    }

    function mint(
        address _to,
        uint256 _tokenId
    ) external _serverOrOwner _validAddress(_to) _requireNFTExist(_tokenId) {
        _mint(_to, _tokenId, 1, "0x00");
    }

    function setServer(
        address _newAddress
    ) external _validAddress(_newAddress) onlyOwner {
        server = _newAddress;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function createNFT(
        uint256 _tokenId,
        string memory _name
    ) external _requireNFTNotExist(_tokenId) _validString(_name) {
        addons[_tokenId] = _name;
    }

    // following function needs to be override by solidity
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override(ERC1155, ERC1155Pausable, ERC1155Supply) {
        super._update(from, to, ids, values);
    }

    function uri(
        uint256 _tokenId
    ) public view override(ERC1155) returns (string memory) {
        return
            string.concat(string.concat(baseUrl, _tokenId.toString()), ".json");
    }

    function setBaseUrl(string memory _url) external {
        baseUrl = _url;
    }
}