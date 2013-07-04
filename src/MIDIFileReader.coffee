class MIDIFileReader
  # See http://www.sonicspot.com/guide/midifiles.html for details of MIDI file format
  # Also see http://www.music.mcgill.ca/~ich/classes/mumt306/midiformat.pdf

  HEADER_CHUNK_ID = parseInt('4D546864', 16) # "MThd"
  HEADER_CHUNK_SIZE = 6
  TRACK_CHUNK_ID = parseInt('4D54726B', 16) # "MTrk"


  constructor: (@filepath) ->


  read: (callback) ->
    console.log("Reading #{@filepath}")
    fs.readFile @filepath, (error, buffer) =>
      throw error if error
      @buffer = buffer
      @offset = 0
      @tracks = []
      @_readHeader()
      @_readTrack() for _ in [0...@numTracks] by 1
      callback() if callback
      return


  _readHeader: ->
    throw 'Not a valid MIDI file: missing header chuck ID' unless @_read4() is HEADER_CHUNK_ID
    throw 'Not a valid MIDI file: missing header chuck size' unless @_read4() is HEADER_CHUNK_SIZE
    @formatType = @_read2()
    @numTracks = @_read2()
    @timeDiv = @_read2()
    return


  _readTrack: ->
    throw 'Invalid track chunk ID' unless @_read4() is TRACK_CHUNK_ID
    trackNumBytes = @_read4()
    console.log "Track has #{trackNumBytes} bytes" if DEBUG
    @_read1() for _ in [0...trackNumBytes] by 1
    return


  # read next 4 bytes
  _read4: ->
    data = @buffer.readUInt32BE(@offset)
    @offset += 4
    console.log '>',data if DEBUG
    data


  # read next 2 bytes
  _read2: ->
    data = @buffer.readUInt16BE(@offset)
    @offset += 2
    console.log '>',data if DEBUG
    data


  _read1: ->
    data = @buffer.readUInt8(@offset)
    @offset += 1
    console.log '>',data if DEBUG
    data
