// SPDX-License-Identifier: UNLICENSED
// Sources flattened with hardhat v2.5.0 https://hardhat.org


// File contracts/shared/interfaces/IAdminProjectRouter.sol

pragma solidity >=0.6.0;

interface IAdminProjectRouter {
  function isSuperAdmin(address _addr, string calldata _project) external view returns (bool);

  function isAdmin(address _addr, string calldata _project) external view returns (bool);
}


// File contracts/shared/abstracts/Authorization.sol

pragma solidity >=0.6.0;

abstract contract Authorization {
  IAdminProjectRouter public adminRouter;
  string public PROJECT;

  modifier onlySuperAdmin() {
    require(adminRouter.isSuperAdmin(msg.sender, PROJECT), "Restricted only super admin");
    _;
  }

  modifier onlyAdmin() {
    require(adminRouter.isAdmin(msg.sender, PROJECT), "Restricted only admin");
    _;
  }

  function setAdmin(address _adminRouter) external onlySuperAdmin {
    adminRouter = IAdminProjectRouter(_adminRouter);
  }
}


// File contracts/shared/interfaces/IKAP20/IKAP20.sol

pragma solidity >=0.6.0;

interface IKAP20 {
  function totalSupply() external view returns (uint256);

  function decimals() external view returns (uint8);

  function symbol() external view returns (string memory);

  function name() external view returns (string memory);

  function balanceOf(address account) external view returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function allowance(address _owner, address spender) external view returns (uint256);

  function approve(address spender, uint256 amount) external returns (bool);

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  function adminTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool success);

  event Transfer(address indexed from, address indexed to, uint256 value);

  event Approval(address indexed owner, address indexed spender, uint256 value);
}


// File contracts/shared/interfaces/IKAP20/IKAP20AdminApprove.sol

pragma solidity >=0.6.0;

interface IKAP20AdminApprove is IKAP20 {
  function adminApprove(
    address _owner,
    address _spender,
    uint256 _amount
  ) external returns (bool);
}


// File contracts/shared/interfaces/IKYCBitkubChain.sol

pragma solidity >=0.6.0;

interface IKYCBitkubChain {
  function kycsLevel(address _addr) external view returns (uint256);
}


// File contracts/shared/abstracts/KYCHandler.sol

pragma solidity ^0.8.0;

abstract contract KYCHandler {
  IKYCBitkubChain public kyc;

  uint256 public acceptedKycLevel;
  bool public isActivatedOnlyKycAddress;

  function _activateOnlyKycAddress() internal virtual {
    isActivatedOnlyKycAddress = true;
  }

  function _setKYC(IKYCBitkubChain _kyc) internal virtual {
    kyc = _kyc;
  }

  function _setAcceptedKycLevel(uint256 _kycLevel) internal virtual {
    acceptedKycLevel = _kycLevel;
  }
}


// File contracts/shared/abstracts/Context.sol

pragma solidity ^0.8.0;

abstract contract Context {
  function _msgSender() internal view virtual returns (address) {
    return msg.sender;
  }

  function _msgData() internal view virtual returns (bytes calldata) {
    return msg.data;
  }
}


// File contracts/shared/abstracts/Pausable.sol

pragma solidity ^0.8.0;

abstract contract Pausable is Context {
  event Paused(address account);

  event Unpaused(address account);

  bool private _paused;

  constructor() {
    _paused = false;
  }

  function paused() public view virtual returns (bool) {
    return _paused;
  }

  modifier whenNotPaused() {
    require(!paused(), "Pausable: paused");
    _;
  }

  modifier whenPaused() {
    require(paused(), "Pausable: not paused");
    _;
  }

  function _pause() internal virtual whenNotPaused {
    _paused = true;
    emit Paused(_msgSender());
  }

  function _unpause() internal virtual whenPaused {
    _paused = false;
    emit Unpaused(_msgSender());
  }
}


// File contracts/shared/abstracts/Blacklist.sol

pragma solidity ^0.8.0;

abstract contract Blacklist {
  mapping(address => bool) public blacklist;

  event AddBlacklist(address indexed account, address indexed caller);

  event RevokeBlacklist(address indexed account, address indexed caller);

  modifier notInBlacklist(address account) {
    require(!blacklist[account], "Address is in blacklist");
    _;
  }

  modifier inBlacklist(address account) {
    require(blacklist[account], "Address is not in blacklist");
    _;
  }

  function _addBlacklist(address account) internal virtual notInBlacklist(account) {
    blacklist[account] = true;
    emit AddBlacklist(account, msg.sender);
  }

  function _revokeBlacklist(address account) internal virtual inBlacklist(account) {
    blacklist[account] = false;
    emit RevokeBlacklist(account, msg.sender);
  }
}


// File contracts/shared/interfaces/IKAP20/IKAP20Committee.sol

pragma solidity >=0.6.0;

interface IKAP20Committee is IKAP20 {
  function committee() external view returns (address);

  function setCommittee(address _committee) external;
}


// File contracts/shared/interfaces/IKAP20/IKAP20KYC.sol

pragma solidity >=0.6.0;

interface IKAP20KYC is IKAP20 {
  function activateOnlyKycAddress() external;

  function setKYC(address _kyc) external;

  function setAcceptedKycLevel(uint256 _kycLevel) external;
}


// File contracts/shared/interfaces/IKToken.sol

pragma solidity >=0.6.0;

interface IKToken {
  function internalTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);

  function externalTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external returns (bool);
}


// File contracts/shared/token/KAP20.sol

pragma solidity ^0.8.0;

contract KAP20 is IKAP20, IKAP20Committee, IKAP20KYC, IKToken, KYCHandler, Pausable, Authorization {
  modifier onlyCommittee() {
    require(msg.sender == committee, "Restricted only committee");
    _;
  }

  modifier onlySuperAdminOrTransferRouter() {
    require(
      adminRouter.isSuperAdmin(msg.sender, PROJECT) || msg.sender == transferRouter,
      "Restricted only super admin or transfer router"
    );
    _;
  }

  mapping(address => uint256) _balances;

  mapping(address => mapping(address => uint256)) internal _allowance;

  uint256 public override totalSupply;

  string public override name;
  string public override symbol;
  uint8 public override decimals;

  address public override committee;
  address public transferRouter;

  constructor(
    string memory _name,
    string memory _symbol,
    uint8 _decimals,
    address _adminRouter,
    address _committee,
    address _kyc,
    uint256 _acceptedKycLevel,
    address _transferRouter
  ) {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
    kyc = IKYCBitkubChain(_kyc);
    acceptedKycLevel = _acceptedKycLevel;
    adminRouter = IAdminProjectRouter(_adminRouter);
    committee = _committee;
    transferRouter = _transferRouter;
  }

  function balanceOf(address account) public view virtual override returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) public virtual override whenNotPaused returns (bool) {
    _transfer(msg.sender, recipient, amount);
    return true;
  }

  function allowance(address owner, address spender) public view virtual override returns (uint256) {
    return _allowance[owner][spender];
  }

  function approve(address spender, uint256 amount) public virtual override returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override whenNotPaused returns (bool) {
    _transfer(sender, recipient, amount);

    uint256 currentAllowance = _allowance[sender][msg.sender];
    require(currentAllowance >= amount, "KAP20: transfer amount exceeds allowance");
    unchecked { _approve(sender, msg.sender, currentAllowance - amount); }

    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
    _approve(msg.sender, spender, _allowance[msg.sender][spender] + addedValue);
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
    uint256 currentAllowance = _allowance[msg.sender][spender];
    require(currentAllowance >= subtractedValue, "KAP20: decreased allowance below zero");
    unchecked { _approve(msg.sender, spender, currentAllowance - subtractedValue); }

    return true;
  }

  function _transfer(
    address sender,
    address recipient,
    uint256 amount
  ) internal virtual {
    require(sender != address(0), "KAP20: transfer from the zero address");
    require(recipient != address(0), "KAP20: transfer to the zero address");

    uint256 senderBalance = _balances[sender];
    require(senderBalance >= amount, "KAP20: transfer amount exceeds balance");
    unchecked { _balances[sender] = senderBalance - amount; }
    _balances[recipient] += amount;

    emit Transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "KAP20: mint to the zero address");

    totalSupply += amount;
    _balances[account] += amount;
    emit Transfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount) internal virtual {
    require(account != address(0), "KAP20: burn from the zero address");

    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "KAP20: burn amount exceeds balance");
    unchecked { _balances[account] = accountBalance - amount; }
    totalSupply -= amount;

    emit Transfer(account, address(0), amount);
  }

  function _approve(
    address owner,
    address spender,
    uint256 amount
  ) internal virtual {
    require(owner != address(0), "KAP20: approve from the zero address");
    require(spender != address(0), "KAP20: approve to the zero address");

    _allowance[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function adminTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) public virtual override onlyCommittee returns (bool) {
    require(_balances[sender] >= amount, "KAP20: transfer amount exceed balance");
    require(recipient != address(0), "KAP20: transfer to zero address");
    _balances[sender] -= amount;
    _balances[recipient] += amount;
    emit Transfer(sender, recipient, amount);

    return true;
  }

  function pause() public onlyCommittee {
    _pause();
  }

  function unpause() public onlyCommittee {
    _unpause();
  }

  function internalTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external override whenNotPaused onlySuperAdminOrTransferRouter returns (bool) {
    require(
      kyc.kycsLevel(sender) >= acceptedKycLevel && kyc.kycsLevel(recipient) >= acceptedKycLevel,
      "Only internal purpose"
    );

    _transfer(sender, recipient, amount);
    return true;
  }

  function externalTransfer(
    address sender,
    address recipient,
    uint256 amount
  ) external override whenNotPaused onlySuperAdminOrTransferRouter returns (bool) {
    require(kyc.kycsLevel(sender) >= acceptedKycLevel, "Only internal purpose");

    _transfer(sender, recipient, amount);
    return true;
  }

  function activateOnlyKycAddress() public override onlyCommittee {
    _activateOnlyKycAddress();
  }

  function setKYC(address _kyc) public override onlyCommittee {
    _setKYC(IKYCBitkubChain(_kyc));
  }

  function setAcceptedKycLevel(uint256 _kycLevel) public override onlyCommittee {
    _setAcceptedKycLevel(_kycLevel);
  }

  function setCommittee(address _committee) external override onlyCommittee {
    committee = _committee;
  }

  function setTransferRouter(address _transferRouter) external onlyCommittee {
    transferRouter = _transferRouter;
  }
}




// File contracts/shared/interfaces/IKAP165.sol

pragma solidity ^0.8.0;

interface IKAP165 {
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File contracts/shared/abstracts/KAP165.sol

pragma solidity ^0.8.0;

abstract contract KAP165 is IKAP165 {
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == type(IKAP165).interfaceId;
  }
}


// File contracts/shared/interfaces/IKAP721/IKAP721.sol

pragma solidity ^0.8.0;

interface IKAP721 is IKAP165 {
  event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
  event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
  event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

  function balanceOf(address owner) external view returns (uint256 balance);

  function ownerOf(uint256 tokenId) external view returns (address owner);

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) external;

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) external;

  function adminTransfer(
    address _from,
    address _to,
    uint256 _tokenId
  ) external;

  function internalTransfer(
    address sender,
    address recipient,
    uint256 tokenId
  ) external returns (bool);

  function externalTransfer(
    address sender,
    address recipient,
    uint256 tokenId
  ) external returns (bool);

  function approve(address to, uint256 tokenId) external;

  function getApproved(uint256 tokenId) external view returns (address operator);

  function setApprovalForAll(address operator, bool _approved) external;

  function isApprovedForAll(address owner, address operator) external view returns (bool);

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes calldata data
  ) external;
}


// File contracts/shared/interfaces/IKAP721/IKAP721Metadata.sol


pragma solidity ^0.8.0;

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IKAP721Metadata {
  /**
   * @dev Returns the token collection name.
   */
  function name() external view returns (string memory);

  /**
   * @dev Returns the token collection symbol.
   */
  function symbol() external view returns (string memory);

  /**
   * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
   */
  function tokenURI(uint256 tokenId) external view returns (string memory);
}


// File contracts/shared/interfaces/IKAP721/IKAP721Enumerable.sol

pragma solidity ^0.8.0;

interface IKAP721Enumerable {
  function totalSupply() external view returns (uint256);

  function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

  function tokenByIndex(uint256 index) external view returns (uint256);
}


// File contracts/shared/interfaces/IKAP721/IKAP721Receiver.sol

pragma solidity ^0.8.0;

interface IKAP721Receiver {
  function onKAP721Received(
    address operator,
    address from,
    uint256 tokenId,
    bytes calldata data
  ) external returns (bytes4);
}


// File contracts/shared/libraries/Address.sol

pragma solidity ^0.8.0;

library Address {
  function isContract(address account) internal view returns (bool) {
    // This method relies on extcodesize, which returns 0 for contracts in
    // construction, since the code is only stored at the end of the
    // constructor execution.

    uint256 size;
    assembly {
      size := extcodesize(account)
    }
    return size > 0;
  }

  function sendValue(address payable recipient, uint256 amount) internal {
    require(address(this).balance >= amount, "Address: insufficient balance");

    (bool success, ) = recipient.call{ value: amount }("");
    require(success, "Address: unable to send value, recipient may have reverted");
  }

  function functionCall(address target, bytes memory data) internal returns (bytes memory) {
    return functionCall(target, data, "Address: low-level call failed");
  }

  function functionCall(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal returns (bytes memory) {
    return functionCallWithValue(target, data, 0, errorMessage);
  }

  function functionCallWithValue(
    address target,
    bytes memory data,
    uint256 value
  ) internal returns (bytes memory) {
    return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
  }

  function functionCallWithValue(
    address target,
    bytes memory data,
    uint256 value,
    string memory errorMessage
  ) internal returns (bytes memory) {
    require(address(this).balance >= value, "Address: insufficient balance for call");
    require(isContract(target), "Address: call to non-contract");

    (bool success, bytes memory returndata) = target.call{ value: value }(data);
    return verifyCallResult(success, returndata, errorMessage);
  }

  function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
    return functionStaticCall(target, data, "Address: low-level static call failed");
  }

  function functionStaticCall(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal view returns (bytes memory) {
    require(isContract(target), "Address: static call to non-contract");

    (bool success, bytes memory returndata) = target.staticcall(data);
    return verifyCallResult(success, returndata, errorMessage);
  }

  function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
    return functionDelegateCall(target, data, "Address: low-level delegate call failed");
  }

  function functionDelegateCall(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal returns (bytes memory) {
    require(isContract(target), "Address: delegate call to non-contract");

    (bool success, bytes memory returndata) = target.delegatecall(data);
    return verifyCallResult(success, returndata, errorMessage);
  }

  function verifyCallResult(
    bool success,
    bytes memory returndata,
    string memory errorMessage
  ) internal pure returns (bytes memory) {
    if (success) {
      return returndata;
    } else {
      // Look for revert reason and bubble it up if present
      if (returndata.length > 0) {
        // The easiest way to bubble the revert reason is using memory via assembly

        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }
  }
}


// File contracts/shared/libraries/EnumerableSetUint.sol

pragma solidity >=0.6.0;

library EnumerableSetUint {
  struct UintSet {
    uint256[] _values;
    mapping(uint256 => uint256) _indexes;
  }

  function add(UintSet storage set, uint256 value) internal returns (bool) {
    if (!contains(set, value)) {
      set._values.push(value);
      set._indexes[value] = set._values.length;
      return true;
    } else {
      return false;
    }
  }

  function remove(UintSet storage set, uint256 value) internal returns (bool) {
    uint256 valueIndex = set._indexes[value];
    if (valueIndex != 0) {
      uint256 toDeleteIndex = valueIndex - 1;
      uint256 lastIndex = set._values.length - 1;
      uint256 lastvalue = set._values[lastIndex];
      set._values[toDeleteIndex] = lastvalue;
      set._indexes[lastvalue] = toDeleteIndex + 1;
      set._values.pop();
      delete set._indexes[value];
      return true;
    } else {
      return false;
    }
  }

  function contains(UintSet storage set, uint256 value) internal view returns (bool) {
    return set._indexes[value] != 0;
  }

  function length(UintSet storage set) internal view returns (uint256) {
    return set._values.length;
  }

  function at(UintSet storage set, uint256 index) internal view returns (uint256) {
    require(set._values.length > index, "EnumerableSet: index out of bounds");
    return set._values[index];
  }

  function getAll(UintSet storage set) internal view returns (uint256[] memory) {
    return set._values;
  }

  function get(
    UintSet storage set,
    uint256 _page,
    uint256 _limit
  ) internal view returns (uint256[] memory) {
    require(_page > 0 && _limit > 0);
    uint256 tempLength = _limit;
    uint256 cursor = (_page - 1) * _limit;
    uint256 _uintLength = length(set);
    if (cursor >= _uintLength) {
      return new uint256[](0);
    }
    if (tempLength > _uintLength - cursor) {
      tempLength = _uintLength - cursor;
    }
    uint256[] memory uintList = new uint256[](tempLength);
    for (uint256 i = 0; i < tempLength; i++) {
      uintList[i] = at(set, cursor + i);
    }
    return uintList;
  }
}


// File contracts/shared/libraries/EnumerableMap.sol

pragma solidity >=0.6.0;

library EnumerableMap {
  struct MapEntry {
    bytes32 _key;
    bytes32 _value;
  }

  struct Map {
    MapEntry[] _entries;
    mapping(bytes32 => uint256) _indexes;
  }

  function _set(
    Map storage map,
    bytes32 key,
    bytes32 value
  ) private returns (bool) {
    // We read and store the key's index to prevent multiple reads from the same storage slot
    uint256 keyIndex = map._indexes[key];

    if (keyIndex == 0) {
      // Equivalent to !contains(map, key)
      map._entries.push(MapEntry({ _key: key, _value: value }));
      // The entry is stored at length-1, but we add 1 to all indexes
      // and use 0 as a sentinel value
      map._indexes[key] = map._entries.length;
      return true;
    } else {
      map._entries[keyIndex - 1]._value = value;
      return false;
    }
  }

  function _remove(Map storage map, bytes32 key) private returns (bool) {
    // We read and store the key's index to prevent multiple reads from the same storage slot
    uint256 keyIndex = map._indexes[key];

    if (keyIndex != 0) {
      // Equivalent to contains(map, key)
      // To delete a key-value pair from the _entries array in O(1), we swap the entry to delete with the last one
      // in the array, and then remove the last entry (sometimes called as 'swap and pop').
      // This modifies the order of the array, as noted in {at}.

      uint256 toDeleteIndex = keyIndex - 1;
      uint256 lastIndex = map._entries.length - 1;

      // When the entry to delete is the last one, the swap operation is unnecessary. However, since this occurs
      // so rarely, we still do the swap anyway to avoid the gas cost of adding an 'if' statement.

      MapEntry storage lastEntry = map._entries[lastIndex];

      // Move the last entry to the index where the entry to delete is
      map._entries[toDeleteIndex] = lastEntry;
      // Update the index for the moved entry
      map._indexes[lastEntry._key] = toDeleteIndex + 1; // All indexes are 1-based

      // Delete the slot where the moved entry was stored
      map._entries.pop();

      // Delete the index for the deleted slot
      delete map._indexes[key];

      return true;
    } else {
      return false;
    }
  }

  function _contains(Map storage map, bytes32 key) private view returns (bool) {
    return map._indexes[key] != 0;
  }

  function _length(Map storage map) private view returns (uint256) {
    return map._entries.length;
  }

  function _at(Map storage map, uint256 index) private view returns (bytes32, bytes32) {
    require(map._entries.length > index, "EnumerableMap: index out of bounds");

    MapEntry storage entry = map._entries[index];
    return (entry._key, entry._value);
  }

  function _tryGet(Map storage map, bytes32 key) private view returns (bool, bytes32) {
    uint256 keyIndex = map._indexes[key];
    if (keyIndex == 0) return (false, 0); // Equivalent to contains(map, key)
    return (true, map._entries[keyIndex - 1]._value); // All indexes are 1-based
  }

  function _get(Map storage map, bytes32 key) private view returns (bytes32) {
    uint256 keyIndex = map._indexes[key];
    require(keyIndex != 0, "EnumerableMap: nonexistent key"); // Equivalent to contains(map, key)
    return map._entries[keyIndex - 1]._value; // All indexes are 1-based
  }

  function _get(
    Map storage map,
    bytes32 key,
    string memory errorMessage
  ) private view returns (bytes32) {
    uint256 keyIndex = map._indexes[key];
    require(keyIndex != 0, errorMessage); // Equivalent to contains(map, key)
    return map._entries[keyIndex - 1]._value; // All indexes are 1-based
  }

  // UintToAddressMap

  struct UintToAddressMap {
    Map _inner;
  }

  function set(
    UintToAddressMap storage map,
    uint256 key,
    address value
  ) internal returns (bool) {
    return _set(map._inner, bytes32(key), bytes32(uint256(uint160(value))));
  }

  function remove(UintToAddressMap storage map, uint256 key) internal returns (bool) {
    return _remove(map._inner, bytes32(key));
  }

  function contains(UintToAddressMap storage map, uint256 key) internal view returns (bool) {
    return _contains(map._inner, bytes32(key));
  }

  function length(UintToAddressMap storage map) internal view returns (uint256) {
    return _length(map._inner);
  }

  function at(UintToAddressMap storage map, uint256 index) internal view returns (uint256, address) {
    (bytes32 key, bytes32 value) = _at(map._inner, index);
    return (uint256(key), address(uint160(uint256(value))));
  }

  function tryGet(UintToAddressMap storage map, uint256 key) internal view returns (bool, address) {
    (bool success, bytes32 value) = _tryGet(map._inner, bytes32(key));
    return (success, address(uint160(uint256(value))));
  }

  function get(UintToAddressMap storage map, uint256 key) internal view returns (address) {
    return address(uint160(uint256(_get(map._inner, bytes32(key)))));
  }

  function get(
    UintToAddressMap storage map,
    uint256 key,
    string memory errorMessage
  ) internal view returns (address) {
    return address(uint160(uint256(_get(map._inner, bytes32(key), errorMessage))));
  }
}


// File contracts/shared/libraries/Strings.sol

pragma solidity ^0.8.0;

library Strings {
  bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

  function toString(uint256 value) internal pure returns (string memory) {
    if (value == 0) {
      return "0";
    }
    uint256 temp = value;
    uint256 digits;
    while (temp != 0) {
      digits++;
      temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    while (value != 0) {
      digits -= 1;
      buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
      value /= 10;
    }
    return string(buffer);
  }

  function toHexString(uint256 value) internal pure returns (string memory) {
    if (value == 0) {
      return "0x00";
    }
    uint256 temp = value;
    uint256 length = 0;
    while (temp != 0) {
      length++;
      temp >>= 8;
    }
    return toHexString(value, length);
  }

  function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
    bytes memory buffer = new bytes(2 * length + 2);
    buffer[0] = "0";
    buffer[1] = "x";
    for (uint256 i = 2 * length + 1; i > 1; --i) {
      buffer[i] = _HEX_SYMBOLS[value & 0xf];
      value >>= 4;
    }
    require(value == 0, "Strings: hex length insufficient");
    return string(buffer);
  }
}


// File contracts/shared/token/KAP721.sol

pragma solidity ^0.8.0;

contract KAP721 is KAP165, IKAP721, IKAP721Metadata, IKAP721Enumerable, Authorization, Pausable {
  using Address for address;
  using EnumerableSetUint for EnumerableSetUint.UintSet;
  using EnumerableMap for EnumerableMap.UintToAddressMap;
  using Strings for uint256;

  // Mapping from holder address to their (enumerable) set of owned tokens
  mapping(address => EnumerableSetUint.UintSet) _holderTokens;

  // Enumerable mapping from token ids to their owners
  EnumerableMap.UintToAddressMap private _tokenOwners;

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  // Token name
  string public override name;

  // Token symbol
  string public override symbol;

  // Optional mapping for token URIs
  mapping(uint256 => string) private _tokenURIs;

  // Base URI
  string public baseURI;

  // Accepted KYC level
  uint256 public acceptedKycLevel;

  IKYCBitkubChain public kyc;

  address public committee;

  address public transferRouter;

  modifier onlyCommittee() {
    require(msg.sender == committee, "Restricted only committee");
    _;
  }

  modifier onlySuperAdminOrTransferRouter() {
    require(
      adminRouter.isSuperAdmin(msg.sender, PROJECT) || msg.sender == transferRouter,
      "Restricted only super admin or transfer router"
    );
    _;
  }

  constructor(
    string memory name_,
    string memory symbol_,
    address _adminRouter,
    address _kyc,
    address _committee,
    uint256 _acceptedKycLevel
  ) {
    name = name_;
    symbol = symbol_;
    adminRouter = IAdminProjectRouter(_adminRouter);
    kyc = IKYCBitkubChain(_kyc);
    committee = _committee;
    acceptedKycLevel = _acceptedKycLevel;
  }

  function supportsInterface(bytes4 interfaceId) public view virtual override(KAP165, IKAP165) returns (bool) {
    return
      interfaceId == type(IKAP721).interfaceId ||
      interfaceId == type(IKAP721Metadata).interfaceId ||
      interfaceId == type(IKAP721Enumerable).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  function setCommittee(address _committee) external onlyCommittee {
    committee = _committee;
  }

  function setKYC(address _kyc) external onlyCommittee {
    kyc = IKYCBitkubChain(_kyc);
  }

  function setAcceptedKycLevel(uint256 _kycLevel) external onlyCommittee {
    acceptedKycLevel = _kycLevel;
  }

  function setTransferRouter(address _transferRouter) external onlyCommittee {
    transferRouter = _transferRouter;
  }

  function pause() external onlyCommittee {
    _pause();
  }

  function unpause() external onlyCommittee {
    _unpause();
  }

  function balanceOf(address owner) public view virtual override returns (uint256) {
    require(owner != address(0), "KAP721: balance query for the zero address");
    return _holderTokens[owner].length();
  }

  function ownerOf(uint256 tokenId) public view virtual override returns (address) {
    return _tokenOwners.get(tokenId, "KAP721: owner query for nonexistent token");
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "KAP721Metadata: URI query for nonexistent token");

    string memory _tokenURI = _tokenURIs[tokenId];
    string memory base = baseURI;

    // If there is no base URI, return the token URI.
    if (bytes(base).length == 0) {
      return _tokenURI;
    }
    // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
    if (bytes(_tokenURI).length > 0) {
      return string(abi.encodePacked(base, _tokenURI));
    }
    // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
    return string(abi.encodePacked(base, tokenId.toString()));
  }

  function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
    return _holderTokens[owner].at(index);
  }

  function totalSupply() public view virtual override returns (uint256) {
    // _tokenOwners are indexed by tokenIds, so .length() returns the number of tokenIds
    return _tokenOwners.length();
  }

  function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
    (uint256 tokenId, ) = _tokenOwners.at(index);
    return tokenId;
  }

  function approve(address to, uint256 tokenId) public virtual override whenNotPaused {
    address owner = KAP721.ownerOf(tokenId);
    require(to != owner, "KAP721: approval to current owner");

    require(
      msg.sender == owner || isApprovedForAll(owner, msg.sender),
      "KAP721: approve caller is not owner nor approved for all"
    );

    _approve(to, tokenId);
  }

  function adminApprove(address to, uint256 tokenId) external onlySuperAdmin whenNotPaused {
    address owner = ownerOf(tokenId);
    require(to != owner, "KAP721: approval to current owner");

    require(
      kyc.kycsLevel(owner) >= acceptedKycLevel && (to == address(0) || kyc.kycsLevel(to) >= acceptedKycLevel),
      "KAP721: Owner or to address is not a KYC user"
    );

    _approve(to, tokenId);
  }

  function getApproved(uint256 tokenId) public view virtual override returns (address) {
    require(_exists(tokenId), "KAP721: approved query for nonexistent token");

    return _tokenApprovals[tokenId];
  }

  function setApprovalForAll(address operator, bool approved) public virtual override whenNotPaused {
    require(operator != msg.sender, "KAP721: approve to caller");

    _setApprovalForAll(msg.sender, operator, approved);
  }

  function adminSetApprovalForAll(
    address owner,
    address operator,
    bool approved
  ) external onlySuperAdmin whenNotPaused {
    require(operator != owner, "KAP721: approve to caller");

    require(
      kyc.kycsLevel(owner) >= acceptedKycLevel && kyc.kycsLevel(operator) >= acceptedKycLevel,
      "KAP721: Owner or operator address is not a KYC user"
    );

    _setApprovalForAll(owner, operator, approved);
  }

  function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
    return _operatorApprovals[owner][operator];
  }

  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override whenNotPaused {
    require(_isApprovedOrOwner(msg.sender, tokenId), "KAP721: transfer caller is not owner nor approved");

    _transfer(from, to, tokenId);
  }

  function adminTransfer(
    address _from,
    address _to,
    uint256 _tokenId
  ) external override onlyCommittee {
    require(ownerOf(_tokenId) == _from, "KAP721: transfer of token that is not own"); // internal owner
    require(_to != address(0), "KAP721: transfer to the zero address");

    // Clear approvals from the previous owner
    _approve(address(0), _tokenId);

    _holderTokens[_from].remove(_tokenId);
    _holderTokens[_to].add(_tokenId);

    _tokenOwners.set(_tokenId, _to);

    emit Transfer(_from, _to, _tokenId);
  }

  function internalTransfer(
    address sender,
    address recipient,
    uint256 tokenId
  ) external override onlySuperAdminOrTransferRouter whenNotPaused returns (bool) {
    require(
      kyc.kycsLevel(sender) >= acceptedKycLevel && kyc.kycsLevel(recipient) >= acceptedKycLevel,
      "Only internal purpose"
    );

    _transfer(sender, recipient, tokenId);
    return true;
  }

  function externalTransfer(
    address sender,
    address recipient,
    uint256 tokenId
  ) external override onlySuperAdminOrTransferRouter whenNotPaused returns (bool) {
    require(kyc.kycsLevel(sender) >= acceptedKycLevel, "Only internal purpose");

    _transfer(sender, recipient, tokenId);
    return true;
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override whenNotPaused {
    safeTransferFrom(from, to, tokenId, "");
  }

  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) public virtual override whenNotPaused {
    require(_isApprovedOrOwner(msg.sender, tokenId), "KAP721: transfer caller is not owner nor approved");
    _safeTransfer(from, to, tokenId, _data);
  }

  function _safeTransfer(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) internal virtual {
    _transfer(from, to, tokenId);
    require(_checkOnKAP721Received(from, to, tokenId, _data), "KAP721: transfer to non KAP721Receiver implementer");
  }

  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return _tokenOwners.contains(tokenId);
  }

  function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
    require(_exists(tokenId), "KAP721: operator query for nonexistent token");
    address owner = KAP721.ownerOf(tokenId);
    return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
  }

  function _safeMint(address to, uint256 tokenId) internal virtual {
    _safeMint(to, tokenId, "");
  }

  function _safeMint(
    address to,
    uint256 tokenId,
    bytes memory _data
  ) internal virtual {
    _mint(to, tokenId);
    require(
      _checkOnKAP721Received(address(0), to, tokenId, _data),
      "KAP721: transfer to non KAP721Receiver implementer"
    );
  }

  function _mint(address to, uint256 tokenId) internal virtual {
    require(to != address(0), "KAP721: mint to the zero address");
    require(!_exists(tokenId), "KAP721: token already minted");

    _beforeTokenTransfer(address(0), to, tokenId);

    _holderTokens[to].add(tokenId);

    _tokenOwners.set(tokenId, to);

    emit Transfer(address(0), to, tokenId);
  }

  function _burn(uint256 tokenId) internal virtual {
    address owner = KAP721.ownerOf(tokenId);

    _beforeTokenTransfer(owner, address(0), tokenId);

    // Clear approvals
    _approve(address(0), tokenId);

    // Clear metadata (if any)
    if (bytes(_tokenURIs[tokenId]).length != 0) {
      delete _tokenURIs[tokenId];
    }

    _holderTokens[owner].remove(tokenId);

    _tokenOwners.remove(tokenId);

    emit Transfer(owner, address(0), tokenId);
  }

  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {
    require(KAP721.ownerOf(tokenId) == from, "KAP721: transfer of token that is not own");
    require(to != address(0), "KAP721: transfer to the zero address");

    _beforeTokenTransfer(from, to, tokenId);

    // Clear approvals from the previous owner
    _approve(address(0), tokenId);

    _holderTokens[from].remove(tokenId);
    _holderTokens[to].add(tokenId);

    _tokenOwners.set(tokenId, to);

    emit Transfer(from, to, tokenId);
  }

  function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
    require(_exists(tokenId), "KAP721Metadata: URI set of nonexistent token");
    _tokenURIs[tokenId] = _tokenURI;
  }

  function _setBaseURI(string memory baseURI_) internal virtual {
    baseURI = baseURI_;
  }

  function _checkOnKAP721Received(
    address from,
    address to,
    uint256 tokenId,
    bytes memory _data
  ) private returns (bool) {
    if (to.isContract()) {
      try IKAP721Receiver(to).onKAP721Received(msg.sender, from, tokenId, _data) returns (bytes4 retval) {
        return retval == IKAP721Receiver.onKAP721Received.selector;
      } catch (bytes memory reason) {
        if (reason.length == 0) {
          revert("KAP721: transfer to non KAP721Receiver implementer");
        } else {
          assembly {
            revert(add(32, reason), mload(reason))
          }
        }
      }
    } else {
      return true;
    }
  }

  function _approve(address to, uint256 tokenId) internal virtual {
    _tokenApprovals[tokenId] = to;
    emit Approval(KAP721.ownerOf(tokenId), to, tokenId);
  }

  function _setApprovalForAll(
    address owner,
    address operator,
    bool approved
  ) internal virtual {
    _operatorApprovals[owner][operator] = approved;
    emit ApprovalForAll(owner, operator, approved);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual {}
}
