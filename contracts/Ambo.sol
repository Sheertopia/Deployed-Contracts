//                                 *@ @@@@@@@@@@ @#                                
//                            @@, @  %@@@/@ @@@@@@@@@@@@                           
//                      ./@# &@@%@@&&@@@@@%@@          &(@@@#*                     
//                   /#@@@@@@@@@@@@@@@@@@@@@@@@@@&,@@@@@@&@@@@@&                   
//                 &@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@(                
//               *@@@@@@@@@@@@@@@@@@@@@@@@.,@@@@@@@@@@@@@@@@@@@@@@@@,              
//             *@@* *@@@@@@@*#*@@@@@@@@@@@@ &@@@@@@@@@@@*#@@@@@@@@@@@@#            
//            /@/ # #@@@/,         .(/@*,*    ,*#(*         (%@(@@@@@@@(           
//            @*  @&*@(                                       *@@@@@@@@@,          
//          .@@#   &/%/                                        @@*@@@@@@@/         
//         (@@.    ./  /@//    (@                    (&    (#(( /@@@@@@/@@*        
//         *@@  (@@@@&/     *@((@(                  %@@.%(     /#@@@@@@@@@.        
//         (@ %@@@@@@/ *&(    ,&@@&,             **@@@&    *#@/ &@@@@@@@/@.        
//         (@,@@@@@@&#.    .#&. *@@@@@@&%%,,,@@@@@@@#  (%(     #%@@@@@@@@@.        
//         *@@@@@@@@@@@@      (*  ./@@@@@@@@@@@@@ @*         .&@@@@@@@@@@@.        
//         (@@@@@@@@@@@@&(         *..%.&@@&%//&.#         %@@@@@@@@@@@@@@&        
//          .@@@@@@@@@@@@@@@.                           (@@@@@@@@@@@@@@@@          
//            @@@@@@@@@@@@@       ,   @@#        @#       @@@@@@@@@@@@@@,          
//            .@@@@@@@@@@#          (@@& / @@@ @            #@@@@@@@@@@/           
//             #@@@@@@%               @.@/@@@#@,                .@@@@@*            
//                @,                 &    &&    &               &&@@.              
//                 ,@@.               @%      (@             .@@@@(                
//                   (@@@(* %          .   ,@%           (%@@@@@#                  
//                      %@@@@,         #@&@@%         %&@@@@@%                     
//                          #/@@*        .,##      #@@@@##                         
//                                           (    #/                               
                                                                                
                                                                                
                                                                                
// //////((   //////,(/      /(///(,         //// .////////    /(///(*   */////////
//      ..:..   ..    ...  .......  .......  ......   ........    ..:.     ......    ...     ...       
//    :JYJ77J~ ^55~  :557 ~5YJ7??7 ^5YJ7??? :5YY?JYJ!.??JYYY?J: !JYJ?YY?: .5YY??YJ7 .55?   .J55Y:      
//    ~Y5?~^^. ^5YJ!!?YY7 ~5Y?~!!. ^5Y?~!!: :5Y7 .?55:  :5Y7   J5Y:   ?55:.YYJ  755^.5Y?  .J5!!5Y.     
//     ::^!J55:^5Y?^^7Y57 ~5Y7^^~. ^5Y?^^~: :5YYJYYY^   :557   J5Y:   ?55:.YYYJJJ?~ .5Y?  J557755Y.    
//    ^J???JY7 ^55~  :5Y7 ~5YJ???? :5YJ???J.:5Y7 ~YY~   :5Y7    ~JYJJYY7: .YYJ      .YY7 ?5J::::J5J.   
//      ....    ..    ..   . .....  . .....  ..    ..    ..        ...     ..        ..  ..      ..    
                                                                                                 
                                                                        
                                                                                
// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AMBO is ERC20, ERC20Permit, ERC20Votes, ERC20Burnable, Ownable {
    bool public applyTokenLimits;
    bool public enableBlackList;

    address public moderator;

    uint256 public maxHoldLimit;
    uint256 public maxTxnLimit;

    mapping(address => bool) public blackList;
    mapping(address => uint256) public lastBuy;

    event Deposit(address indexed sender, uint256 amount, uint256 balance);

    constructor(uint256 _maxHoldLimit, uint256 _maxTxnLimit)
        ERC20("AMBO", "AMBO")
        ERC20Permit("AMBO")
        Ownable(msg.sender)
    {
        maxHoldLimit = _maxHoldLimit;
        maxTxnLimit = _maxTxnLimit;

        moderator = msg.sender;

        applyTokenLimits = true;
        enableBlackList = true;

        _mint(msg.sender, 42000000 * 10**decimals());
    }

    modifier _moderatorOrOwner() {
        require(
            msg.sender == moderator || msg.sender == owner(),
            "ACCESS RESTRICTED"
        );
        _;
    }

    modifier _validAddress(address _addr) {
        require(_addr != address(0), "INVALID ADDRESS PROVIDED");
        _;
    }

    modifier _checkBlackList(address _from, address _to) {
        if (enableBlackList && _from != address(0x00)) {
            require(blackList[_from] == false, "ADDRESS BLACKLISTED");
            require(blackList[_to] == false, "ADDRESS BLACKLISTED");
        }
        _;
    }

    modifier _txnLimiter(
        address _from,
        address _to,
        uint256 _value
    ) {
        if (applyTokenLimits && _from != address(0x00)) {
            require(
                balanceOf(_to) + _value <= maxHoldLimit,
                "MAX TOKEN HOLDING LIMIT EXCEED"
            );
            require(
                _value <= maxTxnLimit,
                "MAX TOKEN TRANSACTION LIMIT EXCEED"
            );
        }
        _;
    }

    function setMaxHoldLimit(uint256 _value) external _moderatorOrOwner {
        require(
            _value >= totalSupply() / 100,
            "LIMIT SHOULD BE ATLEAST 1 PERCENT OF TOTAL SUPPLY"
        );
        maxHoldLimit = _value;
    }

    function setMaxTxnLimit(uint256 _value) external _moderatorOrOwner {
        require(
            _value >= totalSupply() / 10000,
            "LIMIT SHOULD BE ATLEAST 0.01 PERCENT OF TOTAL SUPPLY"
        );

        maxTxnLimit = _value;
    }

    function setApplyTokenLimits(bool _isApply) external _moderatorOrOwner {
        applyTokenLimits = _isApply;
    }

    function setEnableBlackList(bool _enable) external _moderatorOrOwner {
        enableBlackList = _enable;
    }

    function addToBlackList(address _addr)
        external
        _validAddress(_addr)
        _moderatorOrOwner
    {
        blackList[_addr] = true;
    }

    function removeFromBlackList(address _addr)
        external
        _validAddress(_addr)
        _moderatorOrOwner
    {
        delete blackList[_addr];
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function setModerator(address _moderator)
        external
        _validAddress(_moderator)
        _moderatorOrOwner
    {
        moderator = _moderator;
    }

    /**
     * Overrides IERC6372 functions to make the token & governor timestamp-based
     */
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        override(ERC20, ERC20Votes)
        _checkBlackList(from, to)
        _txnLimiter(from, to, value)
    {
        super._update(from, to, value);
    }

    function nonces(address _owner)
        public
        view
        virtual
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(_owner);
    }

    function withdraw(address _to, uint256 _value)
        external
        _moderatorOrOwner
        _validAddress(_to)
    {
        require(address(this).balance >= _value, "INSUFFICIENT FUNDS");
        payable(_to).transfer(_value);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
}
