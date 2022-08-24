//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct Tier {
    uint256 mintStartIndex;
    uint256 mintCost;
    uint256 mintedAmount;
    uint256 maxMintAmount;
}
struct TierTrack {
    uint256 startIndex;
    uint256 endIndex;
}

contract PlayerDAO is ERC721Enumerable, ReentrancyGuard, Ownable {
    // Buy Token
    address public erc20Token;
    // Base URI
    string private baseURI;
    // To Track Indexes
    uint256 public mintStartIndexTrack;

    // mappings
    mapping(uint256 => Tier) public tierDetails;

    mapping(uint256 => TierTrack) public tierTrack;

    //Events

    event TokenMinted(uint256 tokenId, address owner);
    event SecondaryBuy(uint256 tokenId, address owner);
    event WithDrawnFund(address withdrawer, uint256 tokenId);
    event CreatedTier(uint256 tier, uint256 startIndex, uint256 endIndex);

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    /**
     * @dev Changes buy token
     */
    function setBuyToken(address newERC20Token) public onlyOwner {
        erc20Token = newERC20Token;
    }

    /**
     * @dev Changes the base URI if we want to move things in the future (Callable by owner only)
     */
    function setBaseURI(string memory BaseURI) public onlyOwner {
        baseURI = BaseURI;
    }

    /**
     * @dev Base URI for computing {tokenURI}. Empty by default, can be overriden
     * in child contracts.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /**
     * @dev We are selling tokens based on tier
     * Tier 1: from tokenId 1 to tokenId 100
     * Tier 2: from tokenId 101 to 1000
     * Tier 3: from tokenId 1001 to 10000
     */
    function createTier(
        uint256 tierType,
        uint256 mintCost,
        uint256 maxMintAmount
    ) external onlyOwner {
        require(
            tierType != 0 && tierDetails[tierType].maxMintAmount == 0,
            "Invalid Tier Adding"
        );

        tierDetails[tierType] = Tier(
            mintStartIndexTrack + 1,
            mintCost,
            0,
            maxMintAmount
        );
        tierTrack[tierType] = TierTrack(
            mintStartIndexTrack + 1,
            mintStartIndexTrack += maxMintAmount
        );
        emit CreatedTier(
            tierType,
            tierTrack[tierType].startIndex,
            tierTrack[tierType].endIndex
        );
    }

    /**
     * @dev Mint Token Of Different Tiers created By
     * Owner from Above create Tier
     */
    function mint(uint256 tierType, uint256 numberOfTokens)
        external
        nonReentrant
    {
        Tier memory tier = tierDetails[tierType];
        require(tier.mintedAmount + numberOfTokens <= tier.maxMintAmount);

        IERC20(erc20Token).transferFrom(
            msg.sender,
            address(this),
            tier.mintCost * numberOfTokens
        );

        uint256 tokenId;
        for (uint256 index = 0; index < numberOfTokens; index++) {
            tokenId = tier.mintStartIndex + tier.mintedAmount + index;
            _safeMint(msg.sender, tokenId);
            emit TokenMinted(tokenId, msg.sender);
        }
        tierDetails[tierType].mintedAmount += numberOfTokens;
    }

    function withDrawFund(uint256 tokenId, uint256 tokenTier)
        external
        nonReentrant
    {
        TierTrack memory tier = tierTrack[tokenTier];
        require(
            tokenId <= tier.endIndex && tokenId >= tier.startIndex,
            "Invalid Tier"
        );
        ERC721(address(this)).transferFrom(msg.sender, address(this), tokenId);

        IERC20(erc20Token).transfer(
            msg.sender,
            tierDetails[tokenTier].mintCost
        );
        emit WithDrawnFund(msg.sender, tokenId);
    }

    /**
     * @dev This is Seconday Buy when someone deposit
     * token back to contract to with draw fundS
     */
    function secondaryBuy(uint256 tokenId, uint256 tokenTier)
        external
        nonReentrant
    {
        TierTrack memory tier = tierTrack[tokenTier];
        require(
            tokenId <= tier.endIndex && tokenId >= tier.startIndex,
            "Invalid Tier"
        );
        ERC721(address(this)).transferFrom(address(this), msg.sender, tokenId);

        IERC20(erc20Token).transferFrom(
            msg.sender,
            address(this),
            tierDetails[tokenTier].mintCost
        );
        emit SecondaryBuy(tokenId, msg.sender);
    }
}
