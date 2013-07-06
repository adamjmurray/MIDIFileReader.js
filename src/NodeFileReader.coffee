# FileReader interface for Node.js
class NodeFileReader

  FS = require 'fs'


  constructor: (@filepath) ->


  openFile: (onSuccess,onError) ->
    FS.readFile @filepath, (error, buffer) =>
      if error
        if onError then onError(error) else throw error
      @buffer = buffer
      @byteOffset = 0
      onSuccess() if onSuccess
    return


  # get the next 32 bits as an unsigned integer in big endian byte order
  uInt32BE: ->
    data = @buffer.readUInt32BE(@byteOffset)
    @byteOffset += 4
    data


  # get the next 16 bits as an unsigned integer in big endian byte order
  uInt16BE: ->
    data = @buffer.readUInt16BE(@byteOffset)
    @byteOffset += 2
    data


  # get the next 8 bits as an unsigned integer
  uInt8: ->
    data = @buffer.readUInt8(@byteOffset)
    @byteOffset += 1
    data
