// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract VotePepe {
    mapping(address => uint) public userCurrentNFTBalance;
    uint256 public maxSupply = 100; // Sibaa's currently decided max supply
    uint256 public mintedAmount = 50; // Shibaa's currently minted amount yet

    // ^^ New supply via voting contract CANNOT go below this minted supply

    function artificiallyIncreaseNFTBalanceOfUser() external {
        userCurrentNFTBalance[msg.sender]++;
    }
}

contract Voting {
    struct Proposal {
        uint256 newSupplySuggestion;
        uint256 totalVotes;
    }
    Proposal[] public proposals;
    address private owner;
    address public nftContractAddress;
    uint256 public votingEndTime;
    mapping(address => bool) public hasVoted;
    uint256 public democraticallyFinalizedNewNFTSupply;
    address[] public voters;

    // Events
    event Winner(uint256 oldSupply, uint256 newSupply);
    event NewProposals(uint256[] submittedNewProposals);
    event UpdateVotingEndTime(uint256 newTime);
    event NewVote(
        address voter,
        uint256 proposalNumber,
        uint256 totalVotesForThisProposal
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER_ALLOWED");
        _;
    }

    function submitNewProposals(
        uint256[] calldata newProposals,
        uint256 votingTimeInSeconds
    ) external onlyOwner {
        require(block.timestamp > votingEndTime, "LET_CURRENT_VOTING_END");

        /*
            Empty the state from previous voting.
            Then, re-set the state values for new voting proposals.

            We must empty at the start, because in one case,
            the winner proposal cannot be announced. So, state
            won't be re-set in the winner function during winner announcement.

            That one case is when the new finalized decreased supply is smaller
            than the already minted supply of the NFT smart contract, say, OKAMI.
        */

        for (uint256 i = 0; i < voters.length; i++) {
            delete hasVoted[voters[i]];
        }
        delete democraticallyFinalizedNewNFTSupply;
        delete voters;
        delete proposals;

        /*
            Initialize the state values according to this
            voting session's proposals by the admin
        */

        for (uint256 i = 0; i < newProposals.length; i++) {
            proposals.push(Proposal(newProposals[i], 0));
        }

        votingEndTime = block.timestamp + votingTimeInSeconds;
        delete democraticallyFinalizedNewNFTSupply;
        emit NewProposals(newProposals);
    }

    function changeVotingEndTime(
        uint256 votingTimeInSeconds
    ) external onlyOwner {
        votingEndTime = block.timestamp + votingTimeInSeconds;
        emit UpdateVotingEndTime(votingEndTime);
    }

    function setNFTContractAddress(address contractAddress) external onlyOwner {
        nftContractAddress = contractAddress;
    }

    function vote(uint256 proposalNumber) external {
        require(block.timestamp < votingEndTime, "VOTING_TIME_OVER");
        require(!hasVoted[msg.sender], "CANNOT_VOTE_AGAIN");
        require(
            nftContractAddress != address(0),
            "NFT_CONTRACT_ADDRESS_NOT_SET"
        );
        require(proposalNumber < proposals.length, "PROPOSAL_DOES_NOT_EXIST");

        (bool isSuccessful, bytes memory totalNFTBalance) = nftContractAddress
            .call(
                abi.encodeWithSignature(
                    "userCurrentNFTBalance(address)",
                    msg.sender
                )
            );

        require(isSuccessful, "FAILED_TO_QUERY_VOTE_WEIGHT");
        uint256 voteWeight = uint256(bytes32(totalNFTBalance));
        require(voteWeight > 0, "EXPECTED_NON_ZERO_VOTE_WEIGHT");

        proposals[proposalNumber].totalVotes += voteWeight;
        hasVoted[msg.sender] = true;
        voters.push(msg.sender);

        emit NewVote(
            msg.sender,
            proposalNumber,
            proposals[proposalNumber].totalVotes
        );
    }

    function announceWinnerProposal() external onlyOwner {
        require(block.timestamp >= votingEndTime, "VOTING_NOT_ENDED_YET");
        uint256 winningProposal = 0;
        uint256 winningProposalVotes = 0;

        for (uint256 i = 0; i < proposals.length; i++) {
            if (proposals[i].totalVotes > winningProposalVotes) {
                winningProposal = i;
                winningProposalVotes = proposals[i].totalVotes;
            }
        }

        (
            bool isSuccessful,
            bytes memory alreadyMintedAmount
        ) = nftContractAddress.call(abi.encodeWithSignature("mintedAmount()")); // Our 1155 has custom "mintedAmount" public var

        require(isSuccessful, "FAILED_TO_QUERY_ALREADY_MINTED_AMOUNT");
        require(
            uint256(bytes32(alreadyMintedAmount)) <
                proposals[winningProposal].newSupplySuggestion,
            "ALREADY_MINTED_NFTS_SUPPLY_EXCEEDS_NEW_SUPPLY"
        );

        democraticallyFinalizedNewNFTSupply = proposals[winningProposal]
            .newSupplySuggestion;

        (bool isOK, bytes memory existingSupply) = nftContractAddress.call(
            abi.encodeWithSignature("maxSupply()")
        );

        require(isOK, "FAILED_TO_QUERY_CURRENT_MAX_SUPPLY");

        /*
            Our streamer will listen for this event (Winner).
            It will then see if new supply is more or lesser than
            the previous max supply.

            Accordingly, our server will call then the metadata API
            route point to add more metadata (for increased supply)
            or delete metadeata (in case of decreased supply).
        */

        emit Winner(
            uint256(bytes32(existingSupply)),
            democraticallyFinalizedNewNFTSupply
        );
    }
}
