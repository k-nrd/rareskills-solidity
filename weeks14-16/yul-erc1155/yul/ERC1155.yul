object "ERC1155Token" {
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
      case 0x731133e9{}
      // batchMint(address,uint256[], uint256[], bytes)
      case 0xb48ab8b6 {}
      // burn(address,uint256,uint256)
      case 0xf5298aca{}
      // batchBurn(address,uint256[],uint256[])
      case 0xf6eb127a{}
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
      case 0xf242432a {}
      // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
      case 0x2eb2c2d6{}
      // balanceOf(address,uint256)
      case 0x00fdd58e {
        mstore(0x00, balanceOf(calldataload(0x04), calldataload(0x24)) )
        return(0x00, 0x20)
      }
      // balanceOfBatch(address[],uint256[])
      case 0x4e1273f4 {}
      // setApprovalForAll(address,bool)
      case 0xa22cb465 {}
      // isApprovedForAll(address,bool)
      case 0x9d11d120 {}
      // supportsInterface()
      case 0x585582fb {}
      default {
        revert(0x0,0x0)
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
      function balanceOf(account, id) -> balance {
        balance := sload(balancesAccountToBalanceSlot(account, id))
      }
      function uriLength(id) -> len {
        len := sload(uriIdToString(id))
      }
      function uriData(id) -> data {
        data := sload(add(0x20, uriIdToString(id)))
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
