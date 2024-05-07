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
      let selector := shr(0xe0, calldataload(0))

      switch selector 
      // mint(address,uint256,uint256,bytes)
      case /*0x731133e9*/ 0x54ff8b82 {
        let addr := calldataload(0x04)
        let id := calldataload(0x24)
        let amount := calldataload(0x44)

        let balOffset := balancesAccountToBalanceSlot(addr, id)
        let bal := sload(balOffset)
        sstore(balOffset, add(amount, bal))

        emitTransferSingle(caller(), 0x0, addr, id, amount)

        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // batchMint(address,uint256[], uint256[], bytes)
      case 0xb48ab8b6 {
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // burn(address,uint256,uint256)
      case 0xf5298aca {
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // batchBurn(address,uint256[],uint256[])
      case 0xf6eb127a {
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
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
      case 0x2eb2c2d6 {
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // balanceOf(address,uint256)
      case 0x00fdd58e {
        mstore(0x00, balanceOf(calldataload(0x04), calldataload(0x24)) )
        return(0x00, 0x20)
      }
      // balanceOfBatch(address[],uint256[])
      case 0x4e1273f4 {
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // setApprovalForAll(address,bool)
      case 0xa22cb465 {
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // isApprovedForAll(address,bool)
      case 0x9d11d120 {
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      // supportsInterface()
      case 0x585582fb {
        mstore(0x00, 0x01)
        return(0x00, 0x20)
      }
      default {
        mstore(0x00, 0x01)
        revert(0x00,0x20)
      }

      /* Storage layout */
      function balancesSlot() -> s {
        s := 0
      }
      function balancesIdToAccountsSlot(id) -> s {
        s := mapping(balancesSlot(), id)
      }
      function balancesAccountToBalanceSlot(account, id) -> s {
        s := mapping(balancesIdToAccountsSlot(id), account)
      } 
      function approvalsSlot() -> s {
        s := 1
      }
      function approvalsAccountToOperatorSlot(account) -> s {
        s := mapping(approvalsSlot(), account)
      }
      function approvalsOperatorToApprovalSlot(operator, account) -> s {
        s := mapping(approvalsAccountToOperatorSlot(account), operator)
      } 
      function uriSlot() -> s { 
        s := 2
      }
      function uriIdToString(id) -> s {
        s := mapping(uriSlot(), id)
      }

      /* Storage access */
      function balanceOf(account, id) -> bal {
        bal := sload(balancesAccountToBalanceSlot(account, id))
      }
      function uriLength(id) -> len {
        len := sload(uriIdToString(id))
      }
      function uriData(id) -> data {
        data := sload(add(0x20, uriIdToString(id)))
      }

      /* Events */
      function emitTransferSingle(operator, from, to, id, amount) {
        let signatureHash := 0xc3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62
        mstore(0x00, id)
        mstore(0x20, amount)
        log4(0x00, 0x40, signatureHash, operator, from, to)
      }

      /* Utils */
      function mapping(initialOffset, argument) -> offset {
        mstore(0x00, initialOffset)
        mstore(0x20, argument)
        offset := keccak256(0x00, 0x40)
      }
    }
  }
}
