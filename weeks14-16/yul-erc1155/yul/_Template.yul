object "_Template" {
  code {
    // YOUR CUSTOM CONSTRUCTOR LOGIC GOES HERE

    // copy all runtime code to memory
    datacopy(0, dataoffset("Runtime"), datasize("Runtime"))

    // return code to be deployed
    return(0, datasize("Runtime"))
  }
  object "Runtime" {
    code {
      // YOUR CODE GOES HERE
    }
  }
}
