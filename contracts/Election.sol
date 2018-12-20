pragma solidity >=0.4.22 <0.6.0;

/// @title Election with delegation.
contract Election {
	// This declares a new complex type which will
	// be used for variables later.
	// It will represent a single voter.
	struct Voter {
		uint weight; // weight is accumulated by delegation
		bool voted;  // if true, that person already voted
		address delegate; // person delegated to
		uint vote;   // index of the voted proposal
	}

	// This is a type for a single proposal.
	struct Candidate {
		uint id;
		string name;
		uint voteCount;
	}

	address public chairperson;

	// This declares a state variable that
	// stores a `Voter` struct for each possible address.
	mapping(address => Voter) public voters;

	// stores a `Candidate` struct.
	mapping(uint => Candidate) public candidates;

	// Store Candidates Count
	uint public candidatesCount;
	uint public votersCount;
	uint public votingDuration;
	uint public votingStart;
	uint public nominationStart;
	uint public nominationDuration;
	uint private actionTime = now;

	/// Create a new ballot to choose one of `proposalNames`.
	constructor() public {
		chairperson = msg.sender;
		voters[chairperson].weight = 1;
		votersCount++;
	}

	modifier onlyChairperson {
		require(
			msg.sender == chairperson,
			"Only chairperson can call this function"
		);
		_;
	}

	function nominationPeriod(uint _start, uint _duration) public onlyChairperson {
		nominationStart = _start - actionTime;
		nominationDuration = _duration;
	}

	function votingPeriod(uint _start, uint _duration) public onlyChairperson {
		votingStart = _start - actionTime;
		votingDuration = _duration;
	}

	function addCandidate (string _name) public onlyChairperson {
		require(now > (actionTime + nominationStart) && now < (actionTime + nominationStart + nominationDuration), 'Nomination do not start yet or already finished');
		candidatesCount++;
		candidates[candidatesCount] = Candidate(candidatesCount, _name, 0);
	}

	// Give `voter` the right to vote on this ballot.
	// May only be called by `chairperson`.
	function giveRightToVote(address voter) public {
		// If the first argument of `require` evaluates
		// to `false`, execution terminates and all
		// changes to the state and to Ether balances
		// are reverted.
		// This used to consume all gas in old EVM versions, but
		// not anymore.
		// It is often a good idea to use `require` to check if
		// functions are called correctly.
		// As a second argument, you can also provide an
		// explanation about what went wrong.
		require(
			msg.sender == chairperson,
			"Only chairperson can give right to vote."
		);
		require(
			!voters[voter].voted,
			"The voter already voted."
		);
		require(voters[voter].weight == 0);
		voters[voter].weight = 1;
	}

	/// Delegate your vote to the voter `to`.
	function delegate(address to) public {
		// assigns reference
		Voter storage sender = voters[msg.sender];
		require(!sender.voted, "You already voted.");

		require(to != msg.sender, "Self-delegation is disallowed.");

		// Forward the delegation as long as
		// `to` also delegated.
		// In general, such loops are very dangerous,
		// because if they run too long, they might
		// need more gas than is available in a block.
		// In this case, the delegation will not be executed,
		// but in other situations, such loops might
		// cause a contract to get "stuck" completely.
		while (voters[to].delegate != address(0)) {
			to = voters[to].delegate;

			// We found a loop in the delegation, not allowed.
			require(to != msg.sender, "Found loop in delegation.");
		}

		// Since `sender` is a reference, this
		// modifies `voters[msg.sender].voted`
		sender.voted = true;
		sender.delegate = to;
		Voter storage delegate_ = voters[to];
		if (delegate_.voted) {
			// If the delegate already voted,
			// directly add to the number of votes
			candidates[delegate_.vote].voteCount += sender.weight;
		} else {
			// If the delegate did not vote yet,
			// add to her weight.
			delegate_.weight += sender.weight;
		}
	}

	/// Give your vote (including votes delegated to you)
	/// to proposal `candidates[proposal].name`.
	function vote(uint _candidateId) public {
		Voter storage sender = voters[msg.sender];
		require(sender.weight != 0, "Has no right to vote");
		require(!sender.voted, "Already voted.");
		// require a valid candidate
		require(_candidateId > 0 && _candidateId <= candidatesCount);
		require(now > (actionTime + votingStart) && now < (actionTime + votingStart + votingDuration), 'Elections do not start yet or already finished');
		sender.voted = true;
		sender.vote = _candidateId;

		// If `proposal` is out of the range of the array,
		// this will throw automatically and revert all
		// changes.
		candidates[_candidateId].voteCount += sender.weight;
	}

	/// @dev Computes the winning proposal taking all
	/// previous votes into account.
	function winningCandidate() public view returns (uint winningCandidate_) {
		uint winningVoteCount = 0;
		for (uint i = 1; i <= candidatesCount; i++) {
			if (candidates[i].voteCount > winningVoteCount) {
				winningVoteCount = candidates[i].voteCount;
				winningCandidate_ = i;
			}
		}
	}

	// Calls winningCandidate() function to get the index
	// of the winner contained in the candidates array and then
	// returns the name of the winner
	function winnerName() public view returns (string winnerName_) {
		winnerName_ = candidates[winningCandidate()].name;
	}
}