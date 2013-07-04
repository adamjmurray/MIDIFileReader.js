class MIDIFileReader
  # See http://www.sonicspot.com/guide/midifiles.html for details of MIDI file format

  HEADER_CHUNK_ID = parseInt('4D546864', 16)
  HEADER_CHUNK_SIZE = 6


  constructor: (@filepath) ->


  read: (callback) ->
    console.log("Reading #{@filepath}")
    fs.readFile @filepath, (error, buffer) =>
      throw error if error
      @buffer = buffer
      @offset = 0

      throw 'Not a valid MIDI file: missing header chuck ID' unless @read4() is HEADER_CHUNK_ID
      throw 'Not a valid MIDI file: missing header chuck size' unless @read4() is HEADER_CHUNK_SIZE
      @formatType = @read2()
      @numTracks = @read2()
      @timeDiv = @read2()

      callback() if callback


  # read next 4 bytes
  read4: ->
    data = @buffer.readUInt32BE(@offset)
    @offset += 4
    console.log '>',data if DEBUG
    data


  # read next 2 bytes
  read2: ->
    data = @buffer.readUInt16BE(@offset)
    @offset += 2
    console.log '>',data if DEBUG
    data
