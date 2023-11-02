// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface INFTContract {
    function getVoteWeight(address voter) external view returns (uint256);
}

contract SupplyVotingContractTemplate {
    // Ethereum
    struct Proposal {
        uint256 newSupplySuggestion;
        uint256 votesInFavour;
        uint256 votesAgainst;
    }
    Proposal public proposal;
    address private owner;
    address public nftContractAddress;
    uint256 public votingEndTime;
    uint256 public currentVotingVersion;
    mapping(address => uint256) public hasVoted;
    uint256 public democraticallyFinalizedNewNFTSupply;
    uint256 public successPercentage;

    /**
     * @dev Emitted when a proposal is accepted.
     * @param newSupply The new NFT supply associated with the accepted proposal.
     */
    event ProposalAccepted(uint256 newSupply);

    /**
     * @dev Emitted when a proposal is rejected.
     * @param newSupply The new NFT supply associated with the rejected proposal.
     */
    event ProposalRejected(uint256 newSupply);

    /**
     * @dev Emitted when a new supply proposal is submitted.
     * @param newSupplyProposal The proposed new NFT supply.
     */
    event NewProposal(uint256 newSupplyProposal);

    /**
     * @dev Emitted when the voting end time is updated.
     * @param newTime The new voting end time.
     */
    event UpdateVotingEndTime(uint256 newTime);

    /**
     * @dev Emitted when a new vote is cast.
     * @param voter The address of the voter.
     * @param isVoteInFavour Whether the vote is in favor of the proposal.
     * @param voteWeight The weight of the voter's vote.
     * @param proposalNumber The number of the proposal being voted on.
     * @param totalVotesForThisProposal The total votes for the proposal.
     */
    event NewVote(
        address voter,
        bool isVoteInFavour,
        uint256 voteWeight,
        uint256 proposalNumber,
        uint256 totalVotesForThisProposal
    );

    constructor() {
        owner = msg.sender;
        currentVotingVersion = 0;
    }

    /**
     * @dev Modifier to allow only the contract owner to access certain functions.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER_ALLOWED");
        _;
    }

    modifier onlyApprovedContract() {
        require(
            msg.sender == nftContractAddress,
            "CALLER_NOT_ALLOWED_TO_QUERY_SUPPLY"
        );
        _;
    }

    /**
     * @dev Submit a new supply proposal for the NFT contract.
     * @param newSupplyProposal The proposed new supply.
     * @param votingTimeInSeconds The duration of the voting period in seconds.
     * @param nftContract The address of the NFT contract.
     * @param winningPercentage The percentage required for the proposal to succeed.
     * @notice Only callable by the contract owner.
     * @notice The current voting must have ended before submitting a new proposal.
     * @notice The winning percentage must be between 50% and 100%.
     * @notice The voting period must last at least one day (86400 seconds).
     * @notice block.timestamp The current timestamp.
     * @notice votingEndTime The timestamp when the voting ends.
     * @notice democraticallyFinalizedNewNFTSupply Clear the previous proposal results.
     * @notice proposal Create a new proposal with initial values.
     * @notice currentVotingVersion Increment the voting version.
     * @notice emit NewProposal Emit an event to signal the submission of a new proposal.
     */
    function submitNewProposal(
        uint256 newSupplyProposal,
        uint256 votingTimeInSeconds,
        address nftContract,
        uint256 winningPercentage
    ) external onlyOwner {
        require(block.timestamp > votingEndTime, "LET_CURRENT_VOTING_END");
        require(
            winningPercentage >= 50 && winningPercentage <= 100,
            "BAD_WINNING_PERCENTAGE"
        );
        require(
            votingTimeInSeconds >= 86400,
            "VOTING_MUST_LAST_AT_LEAST_ONE_DAY"
        );

        nftContractAddress = nftContract;
        successPercentage = winningPercentage;
        currentVotingVersion++;
        delete democraticallyFinalizedNewNFTSupply;
        proposal = Proposal(newSupplyProposal, 0, 0);
        votingEndTime = block.timestamp + votingTimeInSeconds;
        emit NewProposal(newSupplyProposal);
    }

    /**
     * @dev Cast a vote in favor or against a proposal.
     * @param isVoteInFavour Whether the vote is in favor of the proposal.
     * @notice The current voting period must not be over.
     * @notice You can only vote once per voting version.
     * @notice Voting weight is determined by the voter's NFT balance.
     * @notice The voter's NFT balance must be non-zero to vote.
     * @notice isSuccessful Indicates if the balance query was successful.
     * @notice totalNFTBalance The balance of NFTs owned by the voter.
     * @notice voteWeight The weight of the voter's vote based on their NFT balance.
     * @notice proposal.votesInFavour The total votes in favor of the proposal.
     * @notice proposal.votesAgainst The total votes against the proposal.
     * @notice emit NewVote Emit an event to record the vote.
     */
    function vote(bool isVoteInFavour) external {
        require(block.timestamp < votingEndTime, "VOTING_TIME_OVER");
        require(
            hasVoted[msg.sender] < currentVotingVersion,
            "CANNOT_VOTE_AGAIN"
        );

        hasVoted[msg.sender] = currentVotingVersion;

        uint256 voteWeight = INFTContract(nftContractAddress).getVoteWeight(
            msg.sender
        );
        require(voteWeight > 0, "EXPECTED_NON_ZERO_VOTE_WEIGHT");

        if (isVoteInFavour) {
            proposal.votesInFavour += voteWeight;
        } else {
            proposal.votesAgainst += voteWeight;
        }

        emit NewVote(
            msg.sender,
            isVoteInFavour,
            voteWeight,
            proposal.votesInFavour,
            proposal.votesAgainst
        );
    }

    /**
     * @dev Announce the winner of the proposal based on the successPercentage.
     * @notice The voting must have ended, and the voting must have started.
     * @notice Success is determined by comparing votes in favor to successPercentage.
     * @notice successPercentage The required percentage for a proposal to succeed.
     * @notice democraticallyFinalizedNewNFTSupply The finalized NFT supply if the proposal succeeds.
     * @notice ProposalAccepted Emit an event when the proposal is accepted.
     * @notice ProposalRejected Emit an event when the proposal is rejected.
     */
    function announceWinnerProposal() external onlyOwner {
        require(block.timestamp >= votingEndTime, "VOTING_NOT_ENDED_YET");
        require(votingEndTime > 0, "VOTING_NOT_STARTED_YET");

        /*
            CALCULATIONS EXAMPLE:
            For example: Greater than or equal to 70% votes in favour
            
            votesInFavour >= 70% of total
            inFavor >= 70% of (votesInFavour + votesAgainst)
            votesInFavour >= 70 / 100 of (votesInFavour + votesAgainst)
            100 * votesInFavour >= 70 * (votesInFavour + votesAgainst)
        */

        if (
            100 * proposal.votesInFavour >=
            successPercentage * (proposal.votesInFavour + proposal.votesAgainst)
        ) {
            democraticallyFinalizedNewNFTSupply = proposal.newSupplySuggestion;
            emit ProposalAccepted(proposal.newSupplySuggestion);
        } else {
            emit ProposalRejected(proposal.newSupplySuggestion);
        }

        delete votingEndTime;
    }

    /**
     * @dev Transfer ownership of the contract to a new owner.
     * @param newOwner The address of the new owner.
     * @notice Only callable by the current owner, and the new owner must be a non-zero address.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "NEW_OWNER_ADDRESS_MUST_BE_NON_ZERO");

        owner = newOwner;
    }

    function getFinalizedSupply()
        external
        view
        onlyApprovedContract
        returns (uint256)
    {
        require(votingEndTime > 0, "VOTING_NOT_STARTED_YET");
        require(block.timestamp >= votingEndTime, "VOTING_NOT_ENDED_YET");

        return democraticallyFinalizedNewNFTSupply;
    }
}
