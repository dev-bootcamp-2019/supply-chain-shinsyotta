pragma solidity ^0.5.0;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SupplyChain.sol";

contract TestSupplyChain {
    uint public initialBalance = 1 ether;

    /// @dev Initial variables that we'll re-use.
    enum State { ForSale, Sold, Shipped, Received }
    uint price = 600;
    uint sku = 0;
    string name = "Xiaomi Mi Electric Scooter";
    SupplyChain supplyChain;
    Actor seller;
    Actor buyer;

    function beforeEach () public {
        supplyChain = new SupplyChain();
        seller = new Actor(address(supplyChain));
        buyer = new Actor(address(supplyChain));
        address(buyer).transfer(1000);
        seller.addItem(name, price);
    }

    // buyItem
    /// @dev Testing buyItem at correct price, with correct SKU.
    function testBuyItem () public {
        bool result1 = buyer.buyItem(sku, price);
        Assert.isTrue(result1, "Unable to buy the item.");
    }

    /// @dev Test for failure if user does not send enough funds
    function testBuyWithInsufficientFunds () public {
        bool result1 = buyer.buyItem(sku, (price-5));
        Assert.isFalse(result1, "Oops.  The purchase was made below price.");
    }

    /// @dev Test for purchasing an item that is not for Sale
    function testBuyNonSaleableItem () public {
        bool result1 = buyer.buyItem((sku+1), price);
        Assert.isFalse(result1, "Bought something that was not for sale.");
    }



    // // shipItem
    // /// @dev Testing shipItem 
    function testShipItem () public {
        bool result1 = buyer.buyItem(sku, price);
        Assert.isTrue(result1, "Unable to buy item.");
        bool result2 = seller.shipItem(sku);
        Assert.isTrue(result2, "Unable to ship the item.");
        
        uint state = supplyChain.getState(sku);
        Assert.equal(state, uint(State.Shipped), "Item is not in state: Shipped.");
    }
    // /// @dev Test shipItem for calls that are made by not the seller
    function testShipItemFunctionCalledFromImposter () public {
        bool result1 = buyer.buyItem(sku, price);
        Assert.isTrue(result1, "Unable to buy item.");
        bool result2 = buyer.shipItem(sku);
        Assert.isFalse(result2, "Buyer was able to ship the item.");
        
        uint state = supplyChain.getState(sku);
        Assert.equal(state, uint(State.Sold), "Item is not in state: Sold, as would be expected.");
    }


    // /// @dev test for trying to ship an item that is not marked Sold
    function testShipItemThatIsNotMarkedSold () public {
        uint state = supplyChain.getState(sku);
        Assert.equal(state, uint(State.ForSale), "Item is not in ForSale state, as would be expected.");
        bool result1 = seller.shipItem(sku);
        Assert.isFalse(result1, "Seller was able to ship an unsold item.");
    }


    // // receiveItem
    /// @dev Testing receiveItem 
    // test calling the function from an address that is not the buyer
    // test calling the function on an item not marked Shipped
    function testReceiveItem () public {
        
        bool result1 = buyer.buyItem(sku, price);
        Assert.isTrue(result1, "Buyer unexpectedly unable to buy item.");
        uint state1 = supplyChain.getState(sku);
        Assert.equal(state1, uint(State.Sold), "Item is not in state: Sold, as would be expected.");
        bool result2 = buyer.receiveItem(sku);
        Assert.isFalse(result2, "Buyer is unexpectedly able to receive the item.");
        bool result3 = seller.shipItem(sku);
        Assert.isTrue(result3, "Seller is unexpectedly unable to ship the item.");
        uint state2 = supplyChain.getState(sku);
        Assert.equal(state2, uint(State.Shipped), "Item is not in state: Shipped, as would be expected.");
        bool result4 = seller.receiveItem(sku);
        Assert.isFalse(result4, "Seller is unexpectedly able to receive the item.");
        uint state3 = supplyChain.getState(sku);
        Assert.equal(state3, uint(State.Shipped), "Item is not in state: Shipped, as would be expected.");
        bool result5 = buyer.receiveItem(sku);
        Assert.isTrue(result5, "Seller is unexpectedly unable to receive the item.");
        uint state4 = supplyChain.getState(sku);
        Assert.equal(state4, uint(State.Received), "Item is not in state: Received, as would be expected.");
    }

}

/** 
    @dev 
    * Intention here is to be able to simulate different users/accounts.  
    * This is based around the ThrowProxy contract tutorial found here: https://truffleframework.com/tutorials/testing-for-throws-in-solidity-tests
    * However, the problem is that return type must be specified.
*/
contract Actor {
  address public target;
  bytes data;
  enum State { ForSale, Sold, Shipped, Received }

  constructor (address _target) public {
    target = _target;
  }

  /// @dev Receive Ether to this actor.
  function() external payable {
  }

  function addItem(string memory name, uint price) public {
    SupplyChain(target).addItem(name, price);
  }

  /// @dev Now we reproduce each of the functions that we will be testing in the SupplyChain contract.
  function buyItem(uint sku, uint _price) public returns (bool) {
    (bool result,) = address(target).call.value(_price)(abi.encodeWithSignature("buyItem(uint256)", sku));
    return result;
  }

  function shipItem(uint sku) public returns (bool) {
    (bool result,) = address(target).call(abi.encodeWithSignature("shipItem(uint256)", sku));
    return result;
  }

  function receiveItem(uint sku) public returns (bool) {
    (bool result,) = address(target).call(abi.encodeWithSignature("receiveItem(uint256)", sku));
    return result;
  }

  function getState (uint _sku) public view returns (uint) {
   SupplyChain(target).getState(_sku);
  }
}
