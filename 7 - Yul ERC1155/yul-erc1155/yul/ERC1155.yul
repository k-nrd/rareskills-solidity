object "ERC1155" {
  code {
    // YOUR CUSTOM CONSTRUCTOR LOGIC GOES HERE

    // copy all runtime code to memory
    datacopy(0, dataoffset("runtime"), datasize("runtime"))

    // return code to be deployed
    return(0, datasize("runtime"))
  }
  object "runtime" {
    code {
      switch shr(0xe0, calldataload(0x00)) 
      // mint(address,uint256,uint256,bytes)
      case 0x731133e9 {
        let recipient := calldataload(0x04)
        if iszero(recipient) {
          revert(0x00, 0x00)
        }
        let id := calldataload(0x24)
        let amount := calldataload(0x44)
        let balSlot := balanceOfSlot(recipient, id)
        let bal := sload(balSlot)
        sstore(balSlot, add(amount, bal))
        emitTransferSingle(caller(), 0x00, recipient, id, amount)
        if isContract(recipient) {
          // Recipient is a contract, must be ERC1155Recipient
          callOnERC1155Received(recipient, caller(), 0x00, id, amount, add(calldataload(0x64), 0x04))
        }
      }
      // batchMint(address,uint256[], uint256[], bytes)
      case 0xb48ab8b6 {
        let recipient := calldataload(0x04)
        if iszero(recipient) {
          revert(0x00, 0x00)
        }
        let idsStart := add(calldataload(0x24), 0x04)
        let idsLength := calldataload(idsStart)
        let amountsStart := add(calldataload(0x44), 0x04)
        let amountsLength := calldataload(amountsStart)
        // ids and amounts length must match
        if iszero(eq(idsLength, amountsLength)) {
          revert(0x00, 0x00)
        }
        for { let i := 0 } lt(i, idsLength) { i := add(i, 0x01) } {
          let index := add(0x20, mul(i, 0x20))
          let amount := calldataload(add(amountsStart, index))
          let balSlot := balanceOfSlot(recipient, calldataload(add(idsStart, index)))
          let bal := sload(balSlot)
          sstore(balSlot, add(bal, amount))
        }
        emitTransferBatch(caller(), 0x00, recipient, idsStart, amountsStart, idsLength) 
        if isContract(recipient) {
          callOnERC1155BatchReceived(recipient, caller(), 0x00, idsStart, amountsStart, add(calldataload(0x64), 0x04))
        }
      }
      // burn(address,uint256,uint256)
      case 0xf5298aca {
        let addr := calldataload(0x04)
        let id := calldataload(0x24)
        let amount := calldataload(0x44)
        let balSlot := balanceOfSlot(addr, id)
        let bal := sload(balSlot)
        if lt(bal, amount) {
          revert(0x00, 0x00)
        }
        sstore(balSlot, sub(bal, amount))
        emitTransferSingle(caller(), addr, 0x00, id, amount)
      }
      // batchBurn(address,uint256[],uint256[])
      case 0xf6eb127a {
        let account := calldataload(0x04)
        let idsStart := add(calldataload(0x24), 0x04)
        let idsLength := calldataload(idsStart)
        let amountsStart := add(calldataload(0x44), 0x04)
        let amountsLength := calldataload(amountsStart)
        // ids and amounts length must match
        if iszero(eq(idsLength, amountsLength)) {
          revert(0x00, 0x00)
        }
        for { let i := 0 } lt(i, idsLength) { i := add(i, 0x01) } {
          let index := add(0x20, mul(i, 0x20))
          let amount := calldataload(add(amountsStart, index))
          let balSlot := balanceOfSlot(account, calldataload(add(idsStart, index)))
          let bal := sload(balSlot)
          if lt(bal, amount) {
            revert(0x00, 0x00)
          }
          sstore(balSlot, sub(bal, amount))
        }
        emitTransferBatch(caller(), account, 0x00, idsStart, amountsStart, idsLength)
      }
      // uri(uint256)
      case 0x0e89341c {
        let uriLength := baseUriLength()
        let uriData := baseUriData()

        mstore(0x00, 0x20)
        mstore(0x20, uriLength)
        mstore(0x40, uriData)
        return(0x00, 0x60)
      }
      // setURI(string)
      case 0x02fe5305 {
        let uriStart := add(calldataload(0x04), 0x04)
        let uriLength := calldataload(uriStart)
        sstore(uriSlot(), uriLength)

        let slot := add(uriSlot(), 0x20)
        for { let i := 0 } lt(i, uriLength) { 
          i := add(i, 0x01) 
          slot := add(slot, 0x20)
        } {
          let index := add(0x20, mul(i, 0x20))
          let content := calldataload(add(uriStart, index))
          sstore(slot, content)
        }
        emitURI()
      }
      // safeTransferFrom(address,address,uint256,uint256,bytes)
      case 0xf242432a {
        let toAddr := calldataload(0x24)
        // Don't transfer to address(0), burn instead
        if iszero(toAddr) {
          revert(0x00, 0x00)
        }
        let fromAddr := calldataload(0x04)
        // Either owner or approved operator
        if iszero(or(
          eq(fromAddr, caller()),
          isApproved(fromAddr, caller())
        )) {
          revert(0x00, 0x00)
        }
        let id := calldataload(0x44)
        let amount := calldataload(0x64)
        let fromBalSlot := balanceOfSlot(fromAddr, id)
        let fromBal := sload(fromBalSlot)
        if lt(fromBal, amount) {
          revert(0x00, 0x00)
        }
        let toBalSlot := balanceOfSlot(toAddr, id)
        let toBal := sload(toBalSlot)
        sstore(fromBalSlot, sub(fromBal, amount))
        sstore(toBalSlot, add(toBal, amount))
        emitTransferSingle(caller(), fromAddr, toAddr, id, amount)
        if isContract(toAddr) {
          // Recipient is a contract, must be ERC1155Recipient
          callOnERC1155Received(toAddr, caller(), fromAddr, id, amount, add(calldataload(0x84), 0x04))
        }
      }
      // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
      case 0x2eb2c2d6 {
        let toAddr := calldataload(0x24)
        // Don't transfer to address(0), burn instead
        if iszero(toAddr) {
          revert(0x00, 0x00)
        }
        let fromAddr := calldataload(0x04)
        // Either owner or approved operator
        if iszero(or(
          eq(fromAddr, caller()),
          isApproved(fromAddr, caller())
        )) {
          revert(0x00, 0x00)
        }
        let idsStart := add(calldataload(0x44), 0x04)
        let amountsStart := add(calldataload(0x64), 0x04)
        let idsLength := calldataload(idsStart)
        if iszero(eq(idsLength, calldataload(amountsStart))) {
          revert(0x00, 0x00)
        }
        for { let i := 0 } lt(i, idsLength) { i := add(i, 0x01) } {
          let index := add(0x20, mul(i, 0x20))
          let id := calldataload(add(idsStart, index))
          let amount := calldataload(add(amountsStart, index))
          let fromBalSlot := balanceOfSlot(fromAddr, id)
          let fromBal := sload(fromBalSlot)
          if lt(fromBal, amount) {
            revert(0x00, 0x00)
          }
          let toBalSlot := balanceOfSlot(toAddr, id)
          let toBal := sload(toBalSlot)
          sstore(fromBalSlot, sub(fromBal, amount))
          sstore(toBalSlot, add(toBal, amount))
        }
        emitTransferBatch(caller(), fromAddr, toAddr, idsStart, amountsStart, idsLength)
        if isContract(toAddr) {
          callOnERC1155BatchReceived(toAddr, caller(), fromAddr, idsStart, amountsStart, add(calldataload(0x84), 0x04))
        }
      }
      // balanceOf(address,uint256)
      case 0x00fdd58e {
        mstore(0x00, balanceOf(calldataload(0x04), calldataload(0x24)))
        return(0x00, 0x20)
      }
      // balanceOfBatch(address[],uint256[])
      case 0x4e1273f4 {
        let addrsStart := add(calldataload(0x04), 0x04)
        let addrsLength := calldataload(addrsStart)
        let idsStart := add(calldataload(0x24), 0x04)
        let idsLength := calldataload(idsStart)
        if iszero(eq(idsLength, addrsLength)) {
          revert(0x00, 0x00)
        }
        // Avoid conflicts with balanceOf, which uses 0x00:0x40
        mstore(0x40, 0x20)
        mstore(0x60, idsLength)
        for { let i := 0 } lt(i, addrsLength) { i := add(i, 0x01) } {
          let index := add(0x20, mul(i, 0x20))
          let addr := calldataload(add(addrsStart, index))
          let id := calldataload(add(idsStart, index))
          mstore(add(0x80, mul(i, 0x20)), balanceOf(addr, id))
        }
        return(0x40, add(0x40, mul(idsLength, 0x20)))
      }
      // setApprovalForAll(address,bool)
      case 0xa22cb465 {
        let operator := calldataload(0x04)
        let approved := calldataload(0x24)
        sstore(isApprovedForAllSlot(caller(), operator), approved)
        emitApprovalForAll(caller(), operator, approved)
      }
      // isApprovedForAll(address,address)
      case 0xe985e9c5 {
        mstore(0x00, isApproved(calldataload(0x04), calldataload(0x24)))
        return(0x00, 0x20)
      }
      // supportsInterface()
      case 0x585582fb {
        mstore(0x00, or(0x0e89341c, 0xd9b67a26))
        return(0x00, 0x20)
      }
      default {
        revert(0x00, 0x00)
      }

      /* Storage layout */
      function balancesSlot() -> s {
        s := 0
      }
      function balanceOfSlot(account, id) -> s {
        s := mapping(mapping(balancesSlot(), id), account)
      } 
      function approvalsSlot() -> s {
        s := 1
      }
      function isApprovedForAllSlot(account, operator) -> s {
        s := mapping(mapping(approvalsSlot(), account), operator)
      } 
      function uriSlot() -> s { 
        s := 2
      }

      /* Storage access */
      function balanceOf(account, id) -> bal {
        bal := sload(balanceOfSlot(account, id))
      }
      function isApproved(account, operator) -> approval {
        approval := sload(isApprovedForAllSlot(account, operator))
      }
      function baseUriLength() -> len {
        len := sload(uriSlot())
      }
      function baseUriData() -> uri {
        uri := sload(add(uriSlot(), 0x20))    
      }

      /* Events */
      function emitTransferSingle(operator, from, to, id, amount) {
        mstore(0x00, id)
        mstore(0x20, amount)
        log4(
          0x00,
          0x40,
          0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62,
          operator,
          from,
          to
        )
      }
      function emitTransferBatch(operator, from, to, idsPtr, amountsPtr, length) {
        let size := mul(length, 0x20)
        let idsOffset := 0x40
        let amountsOffset := add(idsOffset, add(size, 0x20))
        mstore(0x00, idsOffset)                             // store offset to id data
        mstore(0x20, amountsOffset)              // store offset to amount data
        mstore(idsOffset, length)                              // store ids length
        mstore(amountsOffset, length)                           // store ampunts length
        calldatacopy(idsOffset, add(idsPtr, 0x20), length)
        calldatacopy(amountsOffset, add(amountsOffset, 0x20), length)
        log4(
          0x00,
          add(amountsOffset, add(size, 0x20)),
          0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb,
          operator,
          from,
          to
        )
      }
      function emitApprovalForAll(account, operator, approved) {
        mstore(0x00, approved)
        log3(
          0x00, 
          0x20, 
          0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31,
          account,
          operator
        )
      }
      function emitURI() {}

      /* Effects */
      function callOnERC1155Received(recipient, operator, from, id, amount, dataStart) {
        let selector := shl(0xe0, 0xf23a6e61)
        // Store function selector
        mstore(0x00, selector)
        // Store fixed-size parameters (caller, from, id, amount)
        mstore(0x04, operator)
        mstore(0x24, from)
        mstore(0x44, id)
        mstore(0x64, amount)
        // Store offset to bytes data 
        mstore(0x84, 0xa0)
        // Copy bytes length and elements into memory
        calldatacopy(0xa4, dataStart, sub(calldatasize(), dataStart))
        // calling onERC1155Received(address,address,uint256,uint256,bytes)
        let success := call(gas(), recipient, 0x00, 0x00, add(calldatasize(), 0x20), 0x00, 0x20)
        if or(
          iszero(success), 
          iszero(eq(mload(0x00), selector))
        ) {
          revert(0x00, 0x00)
        }
      }
      function callOnERC1155BatchReceived(recipient, operator, from, idsStart, amountsStart, dataStart) {
        let selector := shl(0xe0, 0xbc197c81)
        // Calculate sizes
        let idsSize := mul(0x20, calldataload(idsStart)) 
        let amountsSize := mul(0x20, calldataload(amountsStart))
        let dataSize := mul(0x20, calldataload(dataStart))
        // Store function selector
        mstore(0x00, selector)
        // Store fixed-size parameters (caller, from, id, amount)
        mstore(0x04, operator)
        mstore(0x24, from)
        // Store array offsets
        mstore(0x44, 0xa0)
        mstore(0x64, add(0xc0, idsSize))
        mstore(0x84, add(0xe0, mul(idsSize, 0x02)))
        // Copy everything after idsStart
        calldatacopy(0xa4, idsStart, sub(calldatasize(), idsStart))
        // calling onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)
        let success := call(gas(), recipient, 0x00, 0x00, add(calldatasize(), 0x20), 0x00, 0x20)
        if or(
          iszero(success),
          iszero(eq(mload(0x00), selector))
        ) {
          revert(0x00, 0x00)
        }
      }

      /* Utils */
      function mapping(initialSlot, argument) -> slot {
        mstore(0x00, initialSlot)
        mstore(0x20, argument)
        slot := keccak256(0x00, 0x40)
      }
      function isContract(addr) -> bool {
        bool := iszero(iszero(extcodesize(addr)))
      }
    }
  }
}
