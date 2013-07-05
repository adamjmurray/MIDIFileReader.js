class MIDIFileReader
  # See http://www.sonicspot.com/guide/midifiles.html for details of MIDI file format
  # Also see http://www.music.mcgill.ca/~ich/classes/mumt306/midiformat.pdf

  HEADER_CHUNK_ID   = 0x4D546864 # "MThd"
  HEADER_CHUNK_SIZE = 0x06       # All MIDI headers include 6 bytes after the chunk ID and chunk size

  TRACK_CHUNK_ID    = 0x4D54726B # "MTrk"

  META_EVENT  = 0xFF
  SYSEX_EVENT = 0xF0
  SYSEX_CHUNK = 0xF7 # a continuation of a normal SysEx event

  # Meta event types
  SEQ_NUMBER      = 0x00
  TEXT            = 0x01
  COPYRIGHT       = 0x02
  TRACK_NAME      = 0x03
  INSTRUMENT_NAME = 0x04
  LYRICS          = 0x05
  MARKER          = 0x06
  CUE_POINT       = 0x07
  CHANNEL_PREFIX  = 0x20
  END_OF_TRACK    = 0x2F
  TEMPO           = 0x51
  SMPTE_OFFSET    = 0x54
  TIME_SIGNATURE  = 0x58
  KEY_SIGNATURE   = 0x59
  SEQ_SPECIFIC    = 0x7F

  # Channel event types
  NOTE_OFF           = 0x80
  NOTE_ON            = 0x90
  NOTE_AFTERTOUCH    = 0xA0
  CONTROLLER         = 0xB0
  PROGRAM_CHANGE     = 0xC0
  CHANNEL_AFTERTOUCH = 0xD0
  PITCH_BEND         = 0xE0


  constructor: (@filepath) ->


  read: (callback) ->
    console.log("Reading #{@filepath}")
    fs.readFile @filepath, (error, buffer) =>
      throw error if error
      @buffer = buffer
      @byteOffset = 0
      @tracks = []
      @_readHeader()
      @_readTrack(trackNumber) for trackNumber in [1..@numTracks] by 1
      callback() if callback
      return


  _readHeader: ->
    throw 'Not a valid MIDI file: missing header chuck ID' unless @_read4() is HEADER_CHUNK_ID
    throw 'Not a valid MIDI file: missing header chuck size' unless @_read4() is HEADER_CHUNK_SIZE
    @formatType = @_read2()
    @numTracks = @_read2()
    @timeDiv = @_read2() # AKA ticks per beat
    return


  _readTrack: (trackNumber) ->
    throw 'Invalid track chunk ID' unless @_read4() is TRACK_CHUNK_ID

    @track = {number: trackNumber}
    @track.events = @events = []
    @notes = {}
    @timeOffset = 0

    trackNumBytes = @_read4()
    endByte = @byteOffset + trackNumBytes
    @end_of_track = false # Keeps track of whether we saw the meta event for end of track

    while @byteOffset < endByte
      throw "Unexpected end of track event, track has more bytes" if @end_of_track

      deltaTime = @_readVarLen() # in ticks
      @timeOffset += deltaTime

      eventChunkType = @_read1()
      switch eventChunkType
        when META_EVENT then @_readMetaEvent()
        when SYSEX_EVENT,SYSEX_CHUNK then @_readSysExEvent(eventChunkType)
        else @_readChannelEvent((eventChunkType & 0xF0), (eventChunkType & 0x0F))

    throw "Ran out of bytes in the track before encountering the end of track event" unless @end_of_track
    @tracks.push @track
    return


  _readMetaEvent: ->
    type = @_read1()
    length = @_readVarLen()
    if length > 0
      data = []
      data.push @_read1() for _ in [0...length] by 1
    # console.log "Meta Event: type #{type.toString(16)}, data: #{data}" if DEBUG

    event = switch type
      when END_OF_TRACK
        @end_of_track = true
        null
      else {time: @_currentTime(), type: "meta:#{type.toString(16)}", data: data}
      # TODO: proper handling for the other meta event types

    @events.push event if event
    return


  _readSysExEvent: (type) ->
    length = @_readVarLen()
    data = []
    data.push @_read1() for _ in [0...length] by 1
    # console.log "Sysex Event: #{data}" if DEBUG
    # TODO: handle divided events
    @events.push {time: @_currentTime(), type: "sysex:#{type.toString(16)}", data: data}
    return


  _readChannelEvent: (typeMask, channel) ->
    param1 = @_read1()
    param2 = @_read1() unless typeMask == PROGRAM_CHANGE or typeMask == CHANNEL_AFTERTOUCH

    if typeMask == NOTE_ON
      if @notes[param1]
        console.log "Warning: ignoring overlapping note on for pitch #{param1}" # TODO, support this case?
      @notes[param1] = [param2,@_currentTime()] # param1 is the pitch, param2 is velocity
      return # we'll create a 'note' event when we see the corresponding note_off

    if typeMask == NOTE_OFF
      if @notes[param1]
        param3 = param2 # the off velocity, if any
        [param2,startTime] = @notes[param1] # the on velocity
        delete @notes[param1]
        duration = @_currentTime() - startTime
      else
        console.log "Warning: ignoring note off event for pitch #{param1} because there was no corresponding note on event"
        return

    event = switch typeMask
      when NOTE_OFF
        e = {type:'note', pitch:param1, velocity:param2, duration:duration}
        e['off-velocity'] = param3 if param3
        e
      when NOTE_AFTERTOUCH then {type:'note aftertouch', pitch:param1, value:param2}
      when CONTROLLER then {type:'controller', number:param1, value:param2}
      when PROGRAM_CHANGE then {type:'program change', number:param1}
      when CHANNEL_AFTERTOUCH then {type:'channel aftertouch', value:param1}
      when PITCH_BEND then {type:'pitch bend', value:(param1<<7)+param2}
      else console.log "Warning: ignoring unknown event type #{typeMask.toString(16)}"

    event.time = @_currentTime()
    event.channel = channel

    @events.push event
    return


  # current track time, in beats (@timeOffset is in tickets, and @timeDiv is the ticks per beat)
  _currentTime: ->
    @timeOffset/@timeDiv


  # read next 4 bytes
  _read4: ->
    data = @buffer.readUInt32BE(@byteOffset)
    @byteOffset += 4
    data


  # read next 2 bytes
  _read2: ->
    data = @buffer.readUInt16BE(@byteOffset)
    @byteOffset += 2
    data


  _read1: ->
    data = @buffer.readUInt8(@byteOffset)
    @byteOffset += 1
    data


  # read a variable length chunk of bytes
  _readVarLen: ->
    data = 0
    byte = @_read1()
    while (byte & 0x80) != 0
      data = (data << 7) + (byte & 0x7F)
      byte = @_read1()
    (data << 7) + (byte & 0x7F)
