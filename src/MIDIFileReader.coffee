class MIDIFileReader
  # See http://www.sonicspot.com/guide/midifiles.html for details of MIDI file format
  # Also see http://www.music.mcgill.ca/~ich/classes/mumt306/midiformat.pdf

  HEADER_CHUNK_ID   = 0x4D546864 # "MThd"
  HEADER_CHUNK_SIZE = 0x06       # All MIDI headers include 6 bytes after the chunk ID and chunk size

  TRACK_CHUNK_ID    = 0x4D54726B # "MTrk"

  MICROSECONDS_PER_MINUTE = 60000000

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


  constructor: (@stream) ->


  read: (callback) ->
    @stream.open =>
      @tracks = []
      @_readHeader()
      @_readTrack(trackNumber) for trackNumber in [1..@numTracks] by 1
      callback() if callback
    return


  _readHeader: ->
    throw 'Invalid MIDI file: Missing header chuck ID' unless @stream.uInt32BE() is HEADER_CHUNK_ID
    throw 'Invalid MIDI file: Missing header chuck size' unless @stream.uInt32BE() is HEADER_CHUNK_SIZE
    @formatType = @stream.uInt16BE()
    @numTracks = @stream.uInt16BE()
    @timeDiv = @stream.uInt16BE() # AKA ticks per beat
    return


  _readTrack: (trackNumber) ->
    throw 'Invalid MIDI file: Missing track chunk ID' unless @stream.uInt32BE() is TRACK_CHUNK_ID

    @track = {number: trackNumber}
    @track.events = @events = []
    @notes = {}
    @timeOffset = 0

    trackNumBytes = @stream.uInt32BE()
    endByte = @stream.byteOffset + trackNumBytes
    @end_of_track = false # Keeps track of whether we saw the meta event for end of track

    while @stream.byteOffset < endByte
      throw "Invalid MIDI file: End of track event occurred while track has more bytes" if @end_of_track

      deltaTime = @_readVarLen() # in ticks
      @timeOffset += deltaTime

      eventChunkType = @stream.uInt8()
      switch eventChunkType
        when META_EVENT then @_readMetaEvent()
        when SYSEX_EVENT,SYSEX_CHUNK then @_readSysExEvent(eventChunkType)
        else @_readChannelEvent((eventChunkType & 0xF0), (eventChunkType & 0x0F))

    throw "Invalid MIDI file: Missing end of track event" unless @end_of_track
    @tracks.push @track
    return


  _readMetaEvent: ->
    type = @stream.uInt8()

    event = switch type
      when SEQ_NUMBER then {type:'sequence number', number:@_readMetaValue()}
      when TEXT then {type:'text', text:@_readMetaText()}
      when COPYRIGHT then {type:'copyright', text:@_readMetaText()}
      when TRACK_NAME then {type:'track name', text:@_readMetaText()}
      when INSTRUMENT_NAME then {type:'instrument name', text:@_readMetaText()}
      when LYRICS then {type:'lyrics', text:@_readMetaText()}
      when MARKER then {type:'marker', text:@_readMetaText()}
      when CUE_POINT then {type:'cue point', text:@_readMetaText()}
      when CHANNEL_PREFIX then {type:'channel prefix', channel:@_readMetaValue()}
      when END_OF_TRACK then @_readMetaValue(); @end_of_track = true; null # don't treat this as an explicit event
      when TEMPO then {type:'marker', bpm:MICROSECONDS_PER_MINUTE/@_readMetaValue()} # value is microseconds per beat
      when SMPTE_OFFSET then {type:'marker', data:@_readMetaData()} # TODO convert to frame rate, hour, min, sec, fr, subfr
      when TIME_SIGNATURE then {type:'time signature', data:@_readMetaData()} # TODO: interpret the data
      when KEY_SIGNATURE then {type:'key signature', data:@_readMetaData()} # TODO: interpret the data (need signed ints?)
      when SEQ_SPECIFIC then {type:'sequencer specific', data:@_readMetaData()}
      else console.log "Warning: ignoring unknown meta event type #{type.toString(16)}"

    if event
      event.time = @_currentTime()
      @events.push event
    return


  _readSysExEvent: (type) ->
    length = @_readVarLen()
    data = []
    data.push @stream.uInt8() for _ in [0...length] by 1
    # TODO: handle divided events
    @events.push {time: @_currentTime(), type: "sysex:#{type.toString(16)}", data: data}
    return


  _readChannelEvent: (typeMask, channel) ->
    param1 = @stream.uInt8()
    param2 = @stream.uInt8() unless typeMask == PROGRAM_CHANGE or typeMask == CHANNEL_AFTERTOUCH

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
        e['off velocity'] = param3 if param3
        e
      when NOTE_AFTERTOUCH then {type:'note aftertouch', pitch:param1, value:param2}
      when CONTROLLER then {type:'controller', number:param1, value:param2}
      when PROGRAM_CHANGE then {type:'program change', number:param1}
      when CHANNEL_AFTERTOUCH then {type:'channel aftertouch', value:param1}
      when PITCH_BEND then {type:'pitch bend', value:(param1<<7)+param2}
      else console.log "Warning: ignoring unknown channel event type #{typeMask.toString(16)}"

    event.time = @_currentTime()
    event.channel = channel

    @events.push event
    return


  # current track time, in beats (@timeOffset is in tickets, and @timeDiv is the ticks per beat)
  _currentTime: ->
    @timeOffset/@timeDiv


  # Read variable length numeric value in meta events
  _readMetaValue: ->
    length = @_readVarLen()
    value = 0
    value = (value << 8) + @stream.uInt8() for _ in [0...length] by 1
    value


  # Read variable length ASCII text data in meta events
  _readMetaText: ->
    length = @_readVarLen()
    data = []
    data.push @stream.uInt8() for _ in [0...length] by 1
    String.fromCharCode.apply(this,data)


  # Read an array of meta data bytes
  _readMetaData: ->
    length = @_readVarLen()
    if length > 0
      data = []
      data.push @stream.uInt8() for _ in [0...length] by 1
    data


  # read a variable length chunk of bytes
  _readVarLen: ->
    data = 0
    _byte = @stream.uInt8()
    while (_byte & 0x80) != 0
      data = (data << 7) + (_byte & 0x7F)
      _byte = @stream.uInt8()
    (data << 7) + (_byte & 0x7F)
