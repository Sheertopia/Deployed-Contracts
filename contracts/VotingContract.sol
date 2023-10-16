// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INFTContract {
    function getVoteWeight(address voter) external view returns (uint256);
}

contract Voting {
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

    // Events
    event ProposalAccepted(uint256 newSupply);
    event ProposalRejected(uint256 newSupply);
    event NewProposal(uint256 newSupplyProposal);
    event UpdateVotingEndTime(uint256 newTime);
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

    function transferOwnership(address newOwner) external onlyOwner {
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
