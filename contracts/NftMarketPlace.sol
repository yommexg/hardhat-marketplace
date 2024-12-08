// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Custom error definitions to save gas when reverting transactions.
error NftMarketPlace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketPlace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketPlace__PriceNotMet(
    address nftAddress,
    uint256 tokenId,
    uint256 price
);
error NftMarketPlace__NotOwner();
error NftMarketPlace__PriceMustBeAboveZero();
error NftMarketPlace__NotApprovedForMarketPlace();
error NftMarketPlace__NoProceeds();
error NftMarketPlace__TransferFailed();

/// @title NftMarketPlace
/// @author Yomi-Olugbodi Boluwatife
/// @dev A simple marketplace for listing ERC721 NFTs with a price.
/// This contract allows users to list their NFTs for sale, ensuring only the owner can list their item
/// and the NFT is approved for trading within the marketplace.
contract NftMarketPlace is ReentrancyGuard {
    /// @notice Represents a listing for an NFT
    /// @dev A listing includes the price and the seller's address
    struct Listing {
        uint256 price; // Price of the listed NFT in wei.
        address seller; // Seller's address.
    }

    // Event emitted when an item is listed for sale.
    /// @notice Emits when an item is successfully listed.
    /// @param seller The address of the seller listing the item.
    /// @param nftAddress The address of the NFT contract.
    /// @param tokenId The ID of the token being listed.
    /// @param price The price at which the NFT is listed.
    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    // Event emitted when an item is bought.
    /// @notice Emits when an item is successfully bought.
    /// @param buyer The address of the buyer purchasing the item.
    /// @param nftAddress The address of the NFT contract.
    /// @param tokenId The ID of the token being bought.
    /// @param price The price at which the NFT was purchased.
    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    // Event emitted when an item is canceled.
    /// @notice Emits when an item listing is canceled.
    /// @param seller The address of the seller canceling the item.
    /// @param nftAddress The address of the NFT contract.
    /// @param tokenId The ID of the token being canceled.
    event ItemCancelled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    // Mapping to store listings: NFT contract address -> tokenId -> Listing.
    // This allows tracking of each NFT and its listing status.
    mapping(address => mapping(uint256 => Listing)) private s_listings;

    // Seller's Address -> Amount earned
    mapping(address => uint256) private s_proceeds;

    // Modifiers
    /// @dev Modifier that checks if an NFT is already listed.
    /// If the NFT is already listed, it reverts with an error.
    modifier notListed(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert NftMarketPlace__AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    /// @dev Modifier that checks if the caller is the owner of the NFT.
    /// If the caller is not the owner, it reverts with an error.
    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NftMarketPlace__NotOwner();
        }
        _;
    }

    /// @notice Ensures that an NFT is listed for sale on the marketplace.
    /// @dev This modifier checks if the specified NFT (by `nftAddress` and `tokenId`) has a valid price greater than zero in the listing.
    /// If the price is zero or not set, the transaction is reverted with an error indicating the NFT is not listed.
    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NftMarketPlace__NotListed(nftAddress, tokenId);
        }
        _;
    }

    /// @notice List an NFT for sale on the marketplace.
    /// @dev The item will only be listed if it is not already listed, the caller is the owner of the NFT,
    /// and the NFT is approved for the marketplace to transfer.
    /// @param nftAddress The address of the NFT contract.
    /// @param tokenId The ID of the token being listed for sale.
    /// @param price The price of the NFT in wei.
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    )
        external
        notListed(nftAddress, tokenId, msg.sender) // Check if the item is already listed.
        isOwner(nftAddress, tokenId, msg.sender) // Check if the caller is the owner.
    {
        if (price <= 0) {
            revert NftMarketPlace__PriceMustBeAboveZero(); // Price must be greater than zero.
        }

        IERC721 nft = IERC721(nftAddress);
        // Ensure that the contract is approved to transfer the NFT on behalf of the owner.
        if (nft.getApproved(tokenId) != address(this)) {
            revert NftMarketPlace__NotApprovedForMarketPlace();
        }

        // Save the listing in the mapping.
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);

        // Emit the event for successful listing.
        emit ItemListed(msg.sender, nftAddress, tokenId, price);
    }

    /// @notice Allows a user to buy an NFT listed on the marketplace.
    /// @dev This function allows a buyer to purchase an NFT that has been listed for sale. The buyer must send enough ETH to meet the price of the NFT.
    /// The function checks if the NFT is listed, ensures the buyer's payment is sufficient, transfers the NFT to the buyer, and sends the proceeds to the seller.
    /// It also emits an event to signal the successful purchase.
    /// @param nftAddress The address of the NFT contract.
    /// @param tokenId The ID of the token being purchased.
    /// @dev This function uses the `nonReentrant` modifier to prevent reentrancy attacks and `isListed` modifier to ensure the NFT is listed.
    /// @notice The buyer must send at least the listed price. Any excess amount is not refunded.
    function buyItem(
        address nftAddress,
        uint256 tokenId
    ) external payable nonReentrant isListed(nftAddress, tokenId) {
        // Fetch the listing details from the storage.
        Listing memory listedItem = s_listings[nftAddress][tokenId];

        // Check if the sent ETH is enough to meet the price of the NFT.
        if (msg.value < listedItem.price) {
            revert NftMarketPlace__PriceNotMet(
                nftAddress,
                tokenId,
                listedItem.price
            );
        }

        // Accumulate the proceeds of the seller.
        s_proceeds[listedItem.seller] =
            s_proceeds[listedItem.seller] +
            msg.value;

        // Delete the listing as the item has been sold.
        delete (s_listings[nftAddress][tokenId]);

        // Transfer the NFT from the seller to the buyer.
        IERC721(nftAddress).safeTransferFrom(
            listedItem.seller,
            msg.sender,
            tokenId
        );

        // Emit an event to signal the purchase.
        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
    }

    /// @notice Allows a seller to cancel a listed NFT.
    /// @dev This function allows the seller to remove a listing before it is bought. The item must be listed and owned by the caller.
    /// @param nftAddress The address of the NFT contract.
    /// @param tokenId The ID of the token being canceled.
    function cancelItem(
        address nftAddress,
        uint256 tokenId
    )
        external
        isOwner(nftAddress, tokenId, msg.sender) // Ensure the caller is the owner.
        isListed(nftAddress, tokenId) // Ensure the item is listed.
    {
        // Remove the listing from the mapping.
        delete (s_listings[nftAddress][tokenId]);

        // Emit an event indicating the item was canceled.
        emit ItemCancelled(msg.sender, nftAddress, tokenId);
    }

    /// @notice Allows a seller to update the price of a listed NFT.
    /// @dev This function allows the seller to change the price of a listed NFT. The item must already be listed and owned by the caller.
    /// @param nftAddress The address of the NFT contract.
    /// @param tokenId The ID of the token being updated.
    /// @param newPrice The new price of the NFT.
    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    )
        external
        isListed(nftAddress, tokenId) // Ensure the item is listed.
        isOwner(nftAddress, tokenId, msg.sender) // Ensure the caller is the owner.
    {
        if (newPrice <= 0) {
            revert NftMarketPlace__PriceMustBeAboveZero();
        }

        // Update the price of the listed item.
        s_listings[nftAddress][tokenId].price = newPrice;

        // Emit the event to reflect the price change.
        emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    }

    /// @notice Allows a seller to withdraw their earnings from the marketplace.
    /// @dev This function allows the seller to withdraw any proceeds they have accumulated from sold NFTs.
    /// The proceeds are sent to the seller's address. If the transfer fails, the transaction is reverted.
    function withdrawProcceds() external {
        uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) {
            revert NftMarketPlace__NoProceeds(); // Ensure the seller has proceeds to withdraw.
        }

        // Reset the seller's proceeds.
        s_proceeds[msg.sender] = 0;

        // Transfer the proceeds to the seller.
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) {
            revert NftMarketPlace__TransferFailed(); // Ensure the transfer was successful.
        }
    }

    ////////////////////////
    ////Getters Functions///
    ////////////////////////

    /// @notice Retrieves the details of a specific listing.
    /// @param nftAddress The address of the NFT contract.
    /// @param tokenId The ID of the token being queried.
    /// @return The listing for the specified NFT.
    function getListing(
        address nftAddress,
        uint256 tokenId
    ) external view returns (Listing memory) {
        return s_listings[nftAddress][tokenId];
    }

    /// @notice Retrieves the accumulated proceeds for a seller.
    /// @param seller The address of the seller.
    /// @return The amount of proceeds accumulated by the seller.
    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}
