// SPDX-License-Identifier: MIT 
pragma solidity >=0.5.16;

import "./libraries/SafeMath.sol";
import "./libraries/IERC20.sol";

contract PrambCover {
    using SafeMath for uint256;


    struct Protocol {
       string name;
       uint256 rate_per_day;
    }

    struct TokenCapacity {
        address token;
        uint256 capacity;
        uint256 max_capacity;
    }

    struct UserCover {
        uint256 cover_id;
        string protocol;
        address user;
        uint256 amount;
        uint256 cost;
        uint256 start_time;
        uint256 end_time;
        address token;
    }


    uint256 public base_denominator = 1e6;

    address public dev = 0x43abc289364BD20BF625c3273A0a140e33588F1C;
    address public admin;
    address public treasury;

    //storage
    uint256 public current_id = 0;
    mapping(string => Protocol) public protocols;
    mapping(string => mapping(address => TokenCapacity)) public token_capacities;
    mapping(uint256 => UserCover) public user_covers;


    //event

    event CreateProtocol(string name, uint256 rate_per_day);
    event AddTokenCover(string protocol ,address token, uint256 max_capacity);
    event CreateUserCover(uint256 cover_id, string protocol, address user, uint256 amount, uint256 cost, uint256 start_time, uint256 end_time, address token, uint256 current_capacity, string ref_code);
    event ExtendUserCover(uint256 cover_id, string protocol, address user, uint256 amount, uint256 cost, uint256 start_time, uint256 end_time, address token, string ref_code);


    constructor(address _admin, address _treasury) {
        admin = _admin;
        treasury = _treasury;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin || msg.sender == dev, "only admin");
        _;
    }


    function createProtocol(string memory name, uint256 rate_per_day) public onlyAdmin {
        require(protocols[name].rate_per_day != 0, "protocol already exist");
        protocols[name] = Protocol(name, rate_per_day);
        emit CreateProtocol(name, rate_per_day);
    }

    function addTokenCover(string memory protocol_name,address token, uint256 max_capacity) public onlyAdmin {
        require(token_capacities[protocol_name][token].max_capacity != 0, "token already exist");
        token_capacities[protocol_name][token] = TokenCapacity(token, 0, max_capacity);
        emit AddTokenCover(protocol_name,token, max_capacity);
    }

    //update admin
    function updateAdmin(address _admin) public onlyAdmin {
        admin = _admin;
    }

    //update rate protocol
    function updateRateProtocol(string memory protocol_name, uint256 rate_per_day) public onlyAdmin {
        require(protocols[protocol_name].rate_per_day != 0, "protocol not exist");
        protocols[protocol_name].rate_per_day = rate_per_day;
    }
    //update capacity token
    function updateCapacityToken(string memory protocol_name, address token, uint256 new_current_capacity, uint256 new_max_capacity) public onlyAdmin {
        require(token_capacities[protocol_name][token].max_capacity != 0, "token not exist");
        token_capacities[protocol_name][token].max_capacity = new_max_capacity;
        token_capacities[protocol_name][token].capacity = new_current_capacity;

    }

    //withdraw token from contract
    function withdrawToken(address token) public onlyAdmin {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, balance);
    }


    function buyCover(string memory protocol, uint256 amount, uint256 cost, uint256 day_s ,address token, string memory ref_code) public {
        require(protocols[protocol].rate_per_day != 0, "protocol not exist");
        require(token_capacities[protocol][token].capacity != 0, "token not exist");
        require(token_capacities[protocol][token].max_capacity >= amount.add(token_capacities[protocol][token].capacity), "not enough capacity");
        require(cost > 0, "invalid cost");

        string memory _protocol_name = protocol;
        uint256 _amount = amount;

        address user = msg.sender;
        uint256 cover_id = current_id.add(1);
        current_id = cover_id;

        uint256 start_time = block.timestamp;
        uint256 end_time = start_time.add(day_s.mul(60 * 60 * 24));

        uint256 yel = protocols[protocol].rate_per_day.mul(day_s);
        uint256 amount_cost = amount.mul(yel) / base_denominator;

        require(cost == amount_cost, "invalid cost");

        address token_transfer = token;
        
        //transfer token to treasury
        IERC20(token_transfer).transferFrom(user, treasury, amount_cost);

        uint256 capacity = token_capacities[_protocol_name][token_transfer].capacity.add(_amount);

        //update capacity
        token_capacities[_protocol_name][token].capacity = capacity;
        
        UserCover memory user_cover = UserCover(cover_id, _protocol_name, user, _amount, amount_cost, start_time, end_time, token);
        user_covers[cover_id] = user_cover;
        string memory _ref_code = ref_code;
        emit CreateUserCover(cover_id, _protocol_name, user, _amount, amount_cost, start_time, end_time, token_transfer, capacity, _ref_code);
    }

    function extendUserCover(string memory protocol, uint256 cover_id, uint256 cost,uint256 extend_day_s, string memory ref_code) public {
        UserCover memory user_cover = user_covers[cover_id];
        require(user_cover.cover_id == cover_id, "cover not exist");
        require(user_cover.user == msg.sender, "not owner");
        //check protocol
        require(keccak256(abi.encodePacked(user_cover.protocol)) == keccak256(abi.encodePacked(protocol)), "invalid protocol");

        uint256 start_time =  user_cover.start_time;
        uint256 end_time = start_time.add(extend_day_s.mul(60 * 60 * 24));

        uint256 yel = protocols[protocol].rate_per_day.mul(extend_day_s);
        uint256 amount_cost = user_cover.amount.mul(yel) / base_denominator;

        require(cost == amount_cost, "invalid cost");
        //transfer token to treasury
        IERC20(user_cover.token).transferFrom(msg.sender, treasury, cost);


        UserCover memory new_user_cover = UserCover(cover_id, user_cover.protocol, msg.sender, user_cover.amount, cost, start_time, end_time, user_cover.token);
        user_covers[cover_id] = new_user_cover;

        emit ExtendUserCover(cover_id, user_cover.protocol, msg.sender, user_cover.amount, cost, start_time, end_time, user_cover.token, ref_code);
    }



}