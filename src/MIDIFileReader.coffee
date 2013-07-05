class MIDIFileReader
  # See http://www.sonicspot.com/guide/midifiles.html for details of MIDI file format
  # Also see http://www.music.mcgill.ca/~ich/classes/mumt306/midiformat.pdf

  HEADER_CHUNK_ID = parseInt('4D546864', 16) # "MThd"
  HEADER_CHUNK_SIZE = 6
  TRACK_CHUNK_ID = parseInt('4D54726B', 16) # "MTrk"

  UPPER_4_BITS = 0xF0
  LOWER_4_BITS = 0x0F

  EVENT_TYPE_META = 0xFF
  EVENT_TYPE_SYSEX_NORMAL = 0xF0
  EVENT_TYPE_SYSEX_SPECIAL = 0xF7 # a continuation of a normal SysEx event, or a SysEx "authorization" event

  # Channel event types (extracted via UPPER_4_BITS bit mask; the lower 4 bits is the channel for these events)
  NOTE_OFF = 0x80
  NOTE_ON = 0x90
  NOTE_AFTERTOUCH = 0xA0
  CONTROLLER = 0xB0
  PROGRAM_CHANGE = 0xC0
  CHANNEL_AFTERTOUCH = 0xD0
  PITCH_BEND = 0xE0


  constructor: (@filepath) ->


  read: (callback) ->
    console.log("Reading #{@filepath}")
    fs.readFile @filepath, (error, buffer) =>
      throw error if error
      @buffer = buffer
      @byteOffset = 0
      @tracks = []
      @_readHeader()
      @_readTrack(trackIndex) for trackIndex in [0...@numTracks] by 1
      callback() if callback
      return


  _readHeader: ->
    throw 'Not a valid MIDI file: missing header chuck ID' unless @_read4() is HEADER_CHUNK_ID
    throw 'Not a valid MIDI file: missing header chuck size' unless @_read4() is HEADER_CHUNK_SIZE
    @formatType = @_read2()
    @numTracks = @_read2()
    @timeDiv = @_read2() # AKA ticks per beat
    return


  _readTrack: (trackIndex) ->
    throw 'Invalid track chunk ID' unless @_read4() is TRACK_CHUNK_ID

    @track = {number: trackIndex+1}
    @track.events = @events = []
    @notes = {}
    @timeOffset = 0

    trackNumBytes = @_read4()
    endByte = @byteOffset + trackNumBytes
    console.log '------- TRACK --------' if DEBUG
    console.log "Track has #{trackNumBytes} bytes" if DEBUG

    while @byteOffset < endByte
      deltaTime = @_readVarLen() # in ticks
      console.log "Delta time: #{deltaTime}" if DEBUG
      @timeOffset += deltaTime
      eventChunkType = @_read1()

      switch eventChunkType
        when EVENT_TYPE_META then @_readMetaEvent()
        when EVENT_TYPE_SYSEX_NORMAL, EVENT_TYPE_SYSEX_SPECIAL then @_readSysExEvent(eventChunkType)
        else @_readChannelEvent((eventChunkType & UPPER_4_BITS), (eventChunkType & LOWER_4_BITS))

    @tracks.push @track
    return


  _readMetaEvent: ->
    type = @_read1()
    length = @_readVarLen()
    data = []
    data.push @_read1() for _ in [0...length] by 1
    console.log "Meta Event: type #{type.toString(16)}, data: #{data}" if DEBUG
    @events.push {time: @_currentTime(), type: "meta:#{type.toString(16)}", data: data}
    return


  _readSysExEvent: (type) ->
    length = @_readVarLen()
    data = []
    data.push @_read1() for _ in [0...length] by 1
    console.log "Sysex Event: #{data}" if DEBUG
    # TODO: handle divided events, etc
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

    console.log "Channel event: type #{typeName}, channel #{channel}, #{param1} #{param2}" if DEBUG

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
    console.log '>',data.toString(16) if DEBUG
    data


  # read next 2 bytes
  _read2: ->
    data = @buffer.readUInt16BE(@byteOffset)
    @byteOffset += 2
    console.log '>',data.toString(16) if DEBUG
    data


  _read1: ->
    data = @buffer.readUInt8(@byteOffset)
    @byteOffset += 1
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
