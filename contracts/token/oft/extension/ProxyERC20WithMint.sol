// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../OFTCore.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface MultisigWallet {
    function submitTransaction(
        address destination,
        uint value,
        bytes memory data
    ) external returns (uint transactionId);
}

interface BurnableToken {
    function burnFrom(
        address from,
        uint256 amount
    ) external;
}

interface MintableToken {
    function mint(
        address to,
        uint256 amount
    ) external;
}

contract ProxyERC20WithMint is OFTCore {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    
    uint256 public totalTransferred;

    constructor(
        address _lzEndpoint,
        address _proxyToken,
        uint256 _initTotalTransfered,
    ) OFTCore(_lzEndpoint) {
        token = IERC20(_proxyToken);
        totalTransferred = _initTotalTransfered;
    }

    function setTotalTransferred(uint256 _newTotal) external onlyOwner {
        totalTransferred = _newTotal;
    }

    function circulatingSupply() public view virtual override returns (uint) {
        unchecked {
            return token.totalSupply() - token.balanceOf(address(this));
        }
    }

    function _debitFrom(
        address _from,
        uint16,
        bytes memory,
        uint _amount
    ) internal virtual override returns (uint256) {        
        require(_from == _msgSender(), "ProxyOFT: owner is not send caller");
        require(_amount <= totalTransferred, "ProxyOFT: transfer amount exceeds available balance");

        BurnableToken(address(token)).burnFrom(_from, _amount);

        uint256 _balanceBefore = token.balanceOf(msg.sender);
        BurnableToken(address(token)).burnFrom(_from, _amount);
        uint256 _balanceAfter = token.balanceOf(msg.sender);
        
        uint256 _actualAmount = _balanceBefore.sub(_balanceAfter);
        
        totalTransferred = totalTransferred.sub(_actualAmount);

        return _actualAmount;
    }

    function _creditTo(
        uint16,
        address _toAddress,
        uint _amount
    ) internal virtual override {
        MintableToken(address(token)).mint(_toAddress, _amount);

        totalTransferred = totalTransferred.add(_amount);
    }
}
