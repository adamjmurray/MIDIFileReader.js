# FileStream interface for Max (http://cycling74.com/products/max/)
class MaxFileStream

  constructor: (@filepath) ->


  open: (onSuccess,onError) ->
    @file = new File(@filepath)
    if @file.isopen
      @file.byteorder = 'big' # big endian
      @byteOffset = 0
      @endByte = @file.eof
      onSuccess() if onSuccess
      @file.close()
    else
      if onError then onError() else throw 'Could not open file: ' + @filepath
    return


  # get the next 32 bits as an unsigned integer in big endian byte order
  uInt32BE: ->
    data = 0
    data = (data << 8) + @file.readbytes(1) for [0...4]
    @byteOffset += 4
    data


  # get the next 16 bits as an unsigned integer in big endian byte order
  uInt16BE: ->
    data = 0
    data = (data << 8) + @file.readbytes(1) for [0...2]
    @byteOffset += 2
    data


  # get the next 8 bits as an unsigned integer
  uInt8: ->
    if @nextByte
      data = @nextByte
      @nextByte = null
    else
      data = @file.readbytes(1)
      @byteOffset += 1
    data


  # Set the next byte to be returned by uInt8
  # Can be used for look-ahead purposes
  feedByte: (byte) ->
    @nextByte = byte
    return
