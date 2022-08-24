// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

struct Asset {
    uint256 price;
    uint256 collectionId;
    uint256 maxSupply;
    uint256 maxPerWallet;
    uint256 openMintTimestamp; // unix timestamp in seconds
}

contract POQDAOAsset is ERC1155Supply, Ownable, ReentrancyGuard {
    using Strings for uint256;

    string public name;

    string public symbol;

    address public erc20Token;

    // A mapping of the number of Collection minted per collectionId per user
    // assetMintedPerCollectionId[msg.sender][collectionId] => number of minted Asset
    mapping(address => mapping(uint256 => uint256))
        private assetMintedPerCollectionId;

    // A mapping from collectionId to its Asset
    mapping(uint256 => Asset) private collectionToAsset;

    // Define if sale is active
    bool public saleIsActive = false;

    // Event emitted when a Asset is bought
    event AssetBought(
        uint256 collectionId,
        address indexed account,
        uint256 amount
    );

    // Event emitted when a new Asset is created
    event CreatedAsset(
        uint256 price,
        uint256 collectionId,
        uint256 maxSupply,
        uint256 maxPerWallet,
        uint256 openMintTimestamp
    );

    event WithDrawnFund(
        address withdrawer,
        uint256 collectionId,
        uint256 amount
    );

    /**
     * @dev Initializes the contract by setting the name and the token symbol
     */
    constructor() ERC1155("") {
        name = "POQ DAO";
        symbol = "POQ";
    }

    /*
     * Pause sale if active, make active if paused
     */
    function setSaleState(bool newState) public onlyOwner {
        saleIsActive = newState;
    }

    function setBuyToken(address newERC20Token) public onlyOwner {
        erc20Token = newERC20Token;
    }

    /**
     * @dev Retrieves the Asset Details for a given collectionId.
     */
    function getCollectionToAsset(uint256 collectionId)
        external
        view
        returns (Asset memory)
    {
        return collectionToAsset[collectionId];
    }

    /**
     * @dev Contracts the metadata URI for the Asset of the given collectionId.
     *
     * Requirements:
     *
     * - The Asset exists for the given collectionId
     */
    function uri(uint256 collectionId)
        public
        view
        override
        returns (string memory)
    {
        require(
            collectionToAsset[collectionId].collectionId != 0,
            "Invalid collection"
        );
        return
            string(
                abi.encodePacked(
                    super.uri(collectionId),
                    collectionId.toString(),
                    ".json"
                )
            );
    }

    /**
     * Owner-only methods
     */

    /**
     * @dev Sets the base URI for the Collection metadata.
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        require(bytes(baseURI).length != 0, "baseURI cannot be empty");
        _setURI(baseURI);
    }

    /**
     * @dev Sets the parameters on the Collection struct for the given collection.
     * Emits CreatedAsset indicating new assest is created
     */
    function createAsset(
        uint256 price,
        uint256 collectionId,
        uint256 maxSupply,
        uint256 maxPerWallet,
        uint256 openMintTimestamp
    ) external onlyOwner {
        require(
            collectionId != 0 &&
                collectionToAsset[collectionId].collectionId == 0,
            "Invalid collectionId"
        );
        require(
            maxSupply >= maxPerWallet,
            "maxSupply must be greater or equal to maxPerWallet"
        );

        collectionToAsset[collectionId] = Asset(
            price,
            collectionId,
            maxSupply,
            maxPerWallet,
            openMintTimestamp
        );

        emit CreatedAsset(
            price,
            collectionId,
            maxSupply,
            maxPerWallet,
            openMintTimestamp
        );
    }

    /**
     * @dev Mints a set number of Asset for a given collection.
     *
     * Emits a `AssetBought` event indicating the Collection was minted successfully.
     *
     * Requirements:
     *
     * - The current time is within the minting window for the given collection
     * - There are Assets available to mint for the given collection
     * - The user is not trying to mint more than the maxSupply
     * - The user is not trying to mint more than the maxPerWallet
     * - The user has enough ETH for the transaction
     */
    function mintAsset(uint256 collectionId, uint256 amount)
        external
        payable
        nonReentrant
    {
        require(saleIsActive, "Mint is not available right now");
        require(
            collectionId != 0 &&
                collectionToAsset[collectionId].collectionId != 0,
            "Invalid collectionId"
        );
        Asset memory asset = collectionToAsset[collectionId];
        require(
            block.timestamp >= asset.openMintTimestamp,
            "Mint is not available"
        );
        require(totalSupply(collectionId) < asset.maxSupply, "Sold out");
        require(
            totalSupply(collectionId) + amount <= asset.maxSupply,
            "Cannot mint that many"
        );

        uint256 totalMintedAssets = assetMintedPerCollectionId[msg.sender][
            collectionId
        ];
        require(
            totalMintedAssets + amount <= asset.maxPerWallet,
            "Exceeding maximum per wallet"
        );

        IERC20(erc20Token).transferFrom(
            msg.sender,
            address(this),
            amount * asset.price
        );
        assetMintedPerCollectionId[msg.sender][collectionId] =
            totalMintedAssets +
            amount;
        _mint(msg.sender, collectionId, amount, "");

        emit AssetBought(collectionId, msg.sender, amount);
    }

    function withDrawFund(uint256 collectionId, uint256 amount)
        external
        nonReentrant
    {
        ERC1155Supply(address(this)).safeTransferFrom(
            msg.sender,
            address(this),
            collectionId,
            amount,
            ""
        );
        Asset memory asset = collectionToAsset[collectionId];
        IERC20(erc20Token).transfer(msg.sender, amount * asset.price);
        emit WithDrawnFund(msg.sender, collectionId, amount);
    }

    /**
     * @dev Retrieves the number of Asset a user has minted by collectionId.
     */
    function assetMintedByCollectionID(address user, uint256 collectionId)
        external
        view
        returns (uint256)
    {
        return assetMintedPerCollectionId[user][collectionId];
    }
}
