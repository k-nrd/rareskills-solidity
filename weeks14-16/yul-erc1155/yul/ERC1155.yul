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
      switch selector() {
          case 
        }
      function mint() {}
    }
  }
}
