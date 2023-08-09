# Project Lambo &mdash; Smart Contracts

Contained within this GitHub repository lies the heart of Project Lambo's creative expression – six distinctive NFT collections, each a masterpiece in its own right, housed within individual smart contracts. For those eager to embark on a journey of discovery, venture no further than the `/contracts/` directory, where the magic unfolds.

### The 06 NFT Smart Contracts

Envisioned and brought to life through meticulous craftsmanship, the Project Lambo ecosystem is home to not one, not two, but six enchanting NFT collections. These collections are meticulously curated, encapsulating a world of imagination and artistry. Behold the awe-inspiring ensemble:

1.  Deimos Opal
2.  Shiba Opal
3.  Okaami Opal
4.  Lambo Opal
5.  Zeus Pepe
6.  Doge Spartan

### A Signature of Internet Memes: Pepe & Doge

At the heart of Project Lambo's vibrant tapestry, the final two NFT collections shine as the signature meme masterpieces &mdash; Pepe and Doge. These collections resonate with a unique energy, bridging the realms of cultural references and digital artistry. Here, memes transcend their digital origins to become timeless tokens of laughter and camaraderie.

As you navigate the realms of Project Lambo's GitHub repository, each smart contract stands as a testament to our dedication, creativity, and passion. Explore the possibilities that await within `/contracts/`, where innovation and imagination unite in harmonious symphony.

<br>
<hr>
<br>

## A Dive Into Contract Engineering &mdash; For Software Devs

### Reliance on External Libraries

In our pursuit of creating robust and tailored smart contracts, we've harnessed a blend of carefully chosen external libraries in conjunction with our custom code. This amalgamation acknowledges and attributes credit to the open-source code that has contributed to our engineering process. Specifically, we've leveraged the following libraries:

- OpenZeppelin
- Ownable
- Strings

### Smart Contract Implementation: Decisions & Details

Project Lambo has chosen to implement its 6 unique contracts as ERC-1155 tokens, building upon the solid foundation provided by the OpenZeppelin library. To ensure smooth and controlled operations, several customisations have been incorporated into the contracts, adding a layer of restrictions and custom functionality.

- `mint ( .... ) & mintBatch ( .... ):` One notable customization revolves around the token minting process. The minting functionality, encompassing both single and batch minting, has been thoughtfully overridden. Access to these minting functions is now exclusive to the contract owner, achieved through the `OnlyOwner` modifier. This enhancement not only bolsters security by restricting critical operations but also introduces safeguards like defining maximum NFT limits and implementing comprehensive NFT ID range checks.

- `safeTransferFrom ( .... ) & safeBatchTransferFrom ( .... ):` Building on the principle of controlled access to our contract, the safeTransferFrom and safeBatchTransferFrom functions have been customized as well. To maintain a controlled trading environment, a custom modifier named `isTransferAllowed` has been introduced. Through this modifier, Project Lambo enforces a specific restriction: the trading of NFTs is temporarily disabled for a designated period after deployment, specifically until August 13th, 2023. This tactical approach allows Project Lambo to exert a measured level of influence over the initial trading phase, granting the ecosystem time to stabilize before enabling full public trading.

- `uri ( .... ):` Recognizing the pivotal role that metadata plays in enhancing the NFT experience, Project Lambo has also extended the uri function. This function is primarily queried by various marketplaces to retrieve the full metadata URL for NFTs. The actual metadata is, of course, hosted off-chain on Project Lambo's private servers. By thoughtfully handling metadata range and IDs, Project Lambo can ensure the integrity and availability of NFT-related information while seamlessly accommodating external marketplaces.

<br>

**Happy Auditing!**
