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
        let id := calldataload(0x24)
        let amount := calldataload(0x44)

        let balSlot := balanceOfSlot(recipient, id)
        let bal := sload(balSlot)
        sstore(balSlot, add(amount, bal))

        // Recipient is a contract, must be ERC1155Recipient
        if iszero(iszero(extcodesize(recipient))) {
          // Load remaining argument
          let dataOffset := calldataload(0x64)

          let ptr := mload(0x40)
          // Store function selector
          mstore(ptr, shl(0xe0, 0xf23a6e61))
          // Store fixed-size parameters (caller, from, id, amount)
          mstore(add(ptr, 0x04), caller())
          mstore(add(ptr, 0x24), 0x00)
          mstore(add(ptr, 0x44), id)
          mstore(add(ptr, 0x64), amount)
          // Store offset to bytes data 
          mstore(add(ptr, 0x84), 0xa0)

          // Copy bytes length and elements into memory
          let dataStart := add(dataOffset, 0x04)
          let dataSize := sub(calldatasize(), dataStart)
          calldatacopy(add(ptr, 0xa4), dataStart, dataSize)

          // calling onERC1155Received(address,address,uint256,uint256,bytes)
          let success := call(gas(), recipient, 0, ptr, add(dataSize, 0xa4), ptr, 0x20)
          if or(
            iszero(success), 
            iszero(eq(mload(ptr), shl(0xe0, 0xf23a6e61)))
          ) {
            revert(0x00, 0x00)
          }
        }

        emitTransferSingle(caller(), 0x00, recipient, id, amount)
      }
      // batchMint(address,uint256[], uint256[], bytes)
      case 0xb48ab8b6 {
        let recipient := calldataload(0x04)

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

        if iszero(iszero(extcodesize(recipient))) {
          // Load remaining argument
          let dataStart := add(calldataload(0x64), 0x04)
          let dataLength := calldataload(dataStart)

          let ptr := mload(0x40)
          // Store function selector
          mstore(ptr, shl(0xe0, 0xbc197c81))
          // Store fixed-size parameters (caller, from, id, amount)
          mstore(add(ptr, 0x04), caller())
          mstore(add(ptr, 0x24), 0x00)

          // Store array offsets
          mstore(add(ptr, 0x44), 0xa0)
          mstore(add(ptr, 0x64), add(0xa0, add(mul(idsLength, 0x20), 0x20)))
          mstore(add(ptr, 0x84), add(add(0xa0, add(mul(idsLength, 0x20), 0x20)), add(mul(amountsLength, 0x20), 0x20)))

          // Copy IDs length and elements
          mstore(add(ptr, 0xa4), idsLength)
          calldatacopy(add(ptr, 0xc4), idsStart, mul(idsLength, 0x20))
          // Copy amounts length and elements
          mstore(add(ptr, add(0xc4, mul(idsLength, 0x20))), amountsLength)
          calldatacopy(add(ptr, add(0xe4, mul(idsLength, 0x20))), amountsStart, mul(amountsLength, 0x20))
          // Copy data length and elements
          mstore(add(ptr, add(add(0xe4, mul(idsLength, 0x20)), mul(amountsLength, 0x20))), dataLength)
          calldatacopy(add(ptr, add(add(0x104, mul(idsLength, 0x20)), mul(amountsLength, 0x20))), dataStart, dataLength)

          let success := call(
            gas(), 
            recipient, 
            0, 
            ptr, 
            add(add(add(0x104, mul(idsLength, 0x20)), mul(amountsLength, 0x20)), dataLength), 
            ptr, 
            0x20
          )

          if or(
            iszero(success),
            iszero(eq(mload(ptr), shl(0xe0, 0xbc197c81)))
          ) {
            revert(0x00, 0x00)
          }
        }

        emitTransferBatch(caller(), 0x00, recipient, idsStart, amountsStart, idsLength) 
      }
      // burn(address,uint256,uint256)
      case 0xf5298aca {
        let addr := calldataload(0x04)
        let id := calldataload(0x24)
        let amount := calldataload(0x44)

        let balOffset := balanceOfSlot(addr, id)
        let bal := sload(balOffset)
        if lt(bal, amount) {
          revert(0x00, 0x00)
        }
        sstore(balOffset, sub(bal, amount))

        emitTransferSingle(caller(), addr, 0x0, id, amount)
      }
      // batchBurn(address,uint256[],uint256[])
      case 0xf6eb127a {
        let addr:= calldataload(0x04)

        let idsOffset := calldataload(0x24)
        let idsLength := calldataload(add(0x04, idsOffset))

        let amountsOffset := calldataload(0x44) 
        let amountsLength := calldataload(add(0x04, amountsOffset))

        // for {} {} {}
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // uri(uint256)
      case 0x0e89341c {
        // needs to return 
        // [0x00] 0x20 (data offset)
        // [0x20] length (bytes)
        // [0x40] string (UTF-8 encoded)
        let id := calldataload(0x04)
        mstore(0x00, 0x20)
        mstore(0x20, uriLength(id))
        mstore(0x40, uriData(id))
        return(0x00, 0x60)
      }
      // safeTransferFrom(address,address,uint256,uint256,bytes)
      case 0xf242432a {
        let fromAddr := calldataload(0x04)
        let toAddr := calldataload(0x24)
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
      }
      // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
      case 0x2eb2c2d6 {
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // balanceOf(address,uint256)
      case 0x00fdd58e {
        let account := calldataload(0x04)
        let id := calldataload(0x24)

        mstore(0x00, balanceOf(account, id))
        return(0x00, 0x20)
      }
      // balanceOfBatch(address[],uint256[])
      case 0x4e1273f4 {
        let addrsOffset := calldataload(0x04)
        let addrsLength := calldataload(add(0x04, addrsOffset))

        let idsOffset := calldataload(0x24)
        let idsLength := calldataload(add(0x04, idsOffset))

        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // setApprovalForAll(address,bool)
      case 0xb697a0c4 {
        let operator := calldataload(0x04) 
        let approved := calldataload(0x24)

        let approvalOffset := isApprovedForAllSlot(caller(), operator)
        sstore(approvalOffset, approved)
      }
      // isApprovedForAll(address,address)
      case 0xe985e9c5 {
        let account := calldataload(0x04)
        let operator := calldataload(0x24) 

        mstore(0x00, isApproved(account, operator))
        return(0x00, 0x20)
      }
      // supportsInterface()
      case 0x585582fb {
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      default {
        mstore(0x00, 0x01)
        revert(0x00, 0x20)
      }

      /* Storage layout */
      function balancesSlot() -> s {
        s := 1
      }
      function balanceOfSlot(account, id) -> s {
        s := mapping(mapping(balancesSlot(), id), account)
      } 
      function approvalsSlot() -> s {
        s := 2
      }
      function isApprovedForAllSlot(account, operator) -> s {
        s := mapping(mapping(approvalsSlot(), account), operator)
      } 
      function uriSlot() -> s { 
        s := 3
      }
      function uriIdToString(id) -> s {
        s := mapping(uriSlot(), id)
      }

      /* Storage access */
      function balanceOf(account, id) -> bal {
        bal := sload(balanceOfSlot(account, id))
      }
      function isApproved(account, operator) -> approval {
        approval := sload(isApprovedForAllSlot(account, account))
      }
      function uriLength(id) -> len {
        len := sload(uriIdToString(id))
      }
      function uriData(id) -> data {
        data := sload(add(0x20, uriIdToString(id)))
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
        let basePtr := 0xff
        let size := mul(length, 0x20)

        let idsOffset := 0x40
        let amountsOffset := add(idsOffset, add(size, 0x20))
        mstore(basePtr, idsOffset)                             // store offset to id data
        mstore(add(basePtr, 0x20), amountsOffset)              // store offset to amount data
        mstore(add(basePtr, idsOffset), length)                              // store ids length
        mstore(add(basePtr, amountsOffset), length)                           // store ampunts length
        calldatacopy(add(basePtr, idsOffset), add(idsPtr, 0x20), length)
        calldatacopy(add(basePtr, amountsOffset), add(amountsOffset, 0x20), length)

        log4(
          basePtr,
          add(amountsOffset, add(size, 0x20)),
          0x4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb,
          operator,
          from,
          to
        )
      }

      /* Utils */
      function mapping(initialSlot, argument) -> slot {
        mstore(0x00, initialSlot)
        mstore(0x20, argument)
        slot := keccak256(0x00, 0x40)
      }
    }
  }
}
