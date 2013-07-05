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
    console.log '------- TRACK --------'
    console.log "Track has #{trackNumBytes} bytes" if DEBUG
    endOffset = @offset + trackNumBytes
    while @offset < endOffset
      deltaTime = @_readVarLen()
      console.log "Delta time: #{deltaTime}"
      type = @_read1()

      if type == 0xFF # meta event
        type = @_read1()
        length = @_readVarLen()
        data = []
        data.push @_read1() for _ in [0...length] by 1
        console.log "Meta Event: type #{type.toString(16)}, data: #{data}"

      else if type == 0xF0 or type == 0xF7 #sysex
        length = @_readVarLen()
        data = []
        data.push @_read1() for _ in [0...length] by 1
        console.log "Sysex Event: #{data}"
        # TODO: handle divided events, etc

      else
        channel = (type & 0x0F)
        type = (type & 0xF0) >> 4
        param1 = @_read1()
        if type == 0xC or type == 0xD
          param2 = null
        else
          param2 = @_read1()
        console.log "Channel event: type #{type.toString(16)}, channel #{channel}, #{param1} #{param2}"

    return


  # read next 4 bytes
  _read4: ->
    data = @buffer.readUInt32BE(@offset)
    @offset += 4
    console.log '>',data.toString(16) if DEBUG
    data


  # read next 2 bytes
  _read2: ->
    data = @buffer.readUInt16BE(@offset)
    @offset += 2
    console.log '>',data.toString(16) if DEBUG
    data


  _read1: ->
    data = @buffer.readUInt8(@offset)
    @offset += 1
    console.log '>',data.toString(16) if DEBUG
    data


  # read a variable length chunk of bytes
  _readVarLen: ->
    data = 0
    byte = @_read1()
    while (byte & 0x80) != 0
      data = (data << 7) + (byte & 0x7F)
      byte = @_read1()
    (data << 7) + (byte & 0x7F)
