// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./p2pContract.sol";

contract p2pCall is ReentrancyGuard {

    p2pContract public mainContract;

    mapping(uint256=>bool) public isKAPitem;

    uint256 public fee;
    struct FeeLock {
        uint256 feeIndex;
        uint256 valueLock;
        bool isFeeForBoth;
    }
    mapping(uint256=>FeeLock) public feeLock;

    modifier onlyProjectAdmin() {
        require(msg.sender == mainContract.projectAdmin(), "NP"); // NP : Not Permission to call
        _;
    }

    event SetKAPitem(uint256 indexed tokenIndex, bool indexed isKAPitem);
    event ChangeFee(uint256 indexed oldRate, uint256 indexed newRate);
    event WithdrawFee(uint256 indexed tokenIndex, address indexed to, uint256 amount);
    event LockFee(bool indexed isFeeForBoth, uint256 indexed feeIndex, uint256 valueLock);
    event RejectFee(bool indexed isFeeForBoth, uint256 indexed feeIndex, uint256 valueLock);
    event ConfirmFee(bool indexed isFeeForBoth, uint256 indexed feeIndex, uint256 valueLock);

    constructor(address _p2pContract) {
        mainContract = p2pContract(_p2pContract);
        fee = 250;
    }
    
    function setIsKAPitem(uint256 _tokenIndex, bool _isKAPitem) external onlyProjectAdmin {
        isKAPitem[_tokenIndex] = _isKAPitem;
        emit SetKAPitem(_tokenIndex, _isKAPitem);
    }

    function setFee(uint256 _rate) external onlyProjectAdmin {
        emit ChangeFee(fee, _rate);
        fee = _rate;
    }

    function withdrawFee(
        uint256 _tokenIndex,
        uint256 _amount,
        address _to
        ) external onlyProjectAdmin {
        (mainContract.tokens(_tokenIndex)).transfer(_to, _amount);
        emit WithdrawFee(_tokenIndex, _to, _amount);
    }

    function callOfferDeal(
        bool _isFeeForBoth,
        address _receiver,
        uint256 _offerTokenIndex,
        uint256 _offerTokenAmount,
        uint256 _offerNftIndex,
        uint256 _offerNftId,
        uint256 _getTokenIndex,
        uint256 _getTokenAmount,
        uint256 _getNftIndex,
        uint256 _getNftId
        ) external {
        require(
            ((_offerTokenIndex != 0 && _offerNftIndex == 0) || (_offerTokenIndex == 0 && _offerNftIndex != 0)) && ((_getTokenIndex != 0 && _getNftIndex == 0) || (_getTokenIndex == 0 && _getNftIndex != 0)), "IA"
        );  // IA : Invalid Argument
        require(
            (isKAPitem[_offerTokenIndex] == false && _offerNftIndex == 0) || ((isKAPitem[_offerTokenIndex] == true || _offerNftIndex != 0) && (isKAPitem[_getTokenIndex] == false && _getNftIndex == 0)), "IS"
        ); // IS : Invalid Scenario

        uint256 dealIndex = mainContract.dealCount() + 1;

        if (isKAPitem[_offerTokenIndex] == false && _offerNftIndex == 0) { // currency offer scenario
            feeLock[dealIndex].feeIndex = _offerTokenIndex;
            feeLock[dealIndex].valueLock = (_offerTokenAmount/10000) * fee;

        } else if (isKAPitem[_offerTokenIndex] == true || _offerNftIndex != 0) { // KAP item or NFT offer scenario
            feeLock[dealIndex].feeIndex = _getTokenIndex;
            feeLock[dealIndex].valueLock = (_getTokenAmount/10000) * fee;
        }

        feeLock[dealIndex].isFeeForBoth = _isFeeForBoth;

        if (feeLock[dealIndex].isFeeForBoth == true) {
            feeLock[dealIndex].valueLock *= 2;
        }

        (mainContract.tokens(feeLock[dealIndex].feeIndex)).transferFrom(msg.sender, address(this), feeLock[dealIndex].valueLock);

        emit LockFee(_isFeeForBoth, feeLock[dealIndex].feeIndex, feeLock[dealIndex].valueLock);

        mainContract.offerDeal(1, msg.sender, _receiver, _offerTokenIndex, _offerTokenAmount, _offerNftIndex, _offerNftId, _getTokenIndex, _getTokenAmount, _getNftIndex, _getNftId);
    }

    function callRejectDeal(uint256 _index) external nonReentrant {
        require(feeLock[_index].feeIndex != 0, "NF"); // NF : No Fee lock

        (mainContract.tokens(feeLock[_index].feeIndex)).transfer(mainContract.getDeal(_index).sender, feeLock[_index].valueLock);

        emit RejectFee(feeLock[_index].isFeeForBoth, feeLock[_index].feeIndex, feeLock[_index].valueLock);

        delete feeLock[_index];

        mainContract.rejectDeal(_index, msg.sender);
    }

    function callConfirmDeal(uint256 _index, bool _isFeeForBoth) external nonReentrant {
        if (feeLock[_index].isFeeForBoth == false) {
            if (_isFeeForBoth == true) {
                require(feeLock[_index].feeIndex != 0, "NF");

                (mainContract.tokens(feeLock[_index].feeIndex)).transferFrom(mainContract.getDeal(_index).receiver, address(this), feeLock[_index].valueLock * 2);

                (mainContract.tokens(feeLock[_index].feeIndex)).transfer(mainContract.getDeal(_index).sender, feeLock[_index].valueLock);

            } else if (_isFeeForBoth == false) {
                (mainContract.tokens(feeLock[_index].feeIndex)).transferFrom(mainContract.getDeal(_index).receiver, address(this), feeLock[_index].valueLock);
            }
        }

        emit ConfirmFee(feeLock[_index].isFeeForBoth, feeLock[_index].feeIndex, feeLock[_index].valueLock);

        delete feeLock[_index];
        
        mainContract.confirmDeal(_index, msg.sender);
    }
    
}
