class MIDIFileReader
  # For details of MIDI file format, see:
  # http://www.sonicspot.com/guide/midifiles.html
  # http://www.somascape.org/midi/tech/mfile.html
  # http://www.music.mcgill.ca/~ich/classes/mumt306/midiformat.pdf

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
  SEQ_NAME        = 0x03
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

  KEY_VALUE_TO_NAME =
    0:  'C'
    1:  'G'
    2:  'D'
    3:  'A'
    4:  'E'
    5:  'B'
    6:  'F#'
    7:  'C#'
    '-1': 'F'
    '-2': 'Bb'
    '-3': 'Eb'
    '-4': 'Ab'
    '-5': 'Db'
    '-6': 'Gb'
    '-7': 'Cb'


  constructor: (@stream) ->


  read: (callback) ->
    @stream.open =>
      @tracks = []
      @_readHeader()
      @_readTrack(trackNumber) for trackNumber in [1..@numTracks] by 1
      # TODO: inspect @notes data structure and issue warnings if not empty (we missed some note offs)
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
    @endOfTrack = false # Keeps track of whether we saw the meta event for end of track

    while @stream.byteOffset < endByte
      throw "Invalid MIDI file: End of track event occurred while track has more bytes" if @endOfTrack

      deltaTime = @_readVarLen() # in ticks
      @timeOffset += deltaTime

      eventChunkType = @stream.uInt8()
      event = switch eventChunkType
        when META_EVENT then @_readMetaEvent()
        when SYSEX_EVENT,SYSEX_CHUNK then @_readSysExEvent(eventChunkType)
        else @_readChannelEvent(eventChunkType)

      if event
        event.time ?= @_currentTime() # might have been set in _readNoteOff()
        @events.push event

    throw "Invalid MIDI file: Missing end of track event" unless @endOfTrack
    @tracks.push @track
    return


  _readMetaEvent: ->
    type = @stream.uInt8()

    event = switch type
      when SEQ_NUMBER then {type:'sequence number', number:@_readMetaValue()}
      when TEXT then {type:'text', text:@_readMetaText()}
      when COPYRIGHT then {type:'copyright', text:@_readMetaText()}
      when SEQ_NAME then {type:'sequence name', text:@_readMetaText()}
      when INSTRUMENT_NAME then {type:'instrument name', text:@_readMetaText()}
      when LYRICS then {type:'lyrics', text:@_readMetaText()}
      when MARKER then {type:'marker', text:@_readMetaText()}
      when CUE_POINT then {type:'cue point', text:@_readMetaText()}
      when CHANNEL_PREFIX then {type:'channel prefix', channel:@_readMetaValue()}
      when END_OF_TRACK then @_readMetaValue(); @endOfTrack = true; null # don't treat this as an explicit event
      when TEMPO then {type:'tempo', bpm:MICROSECONDS_PER_MINUTE/@_readMetaValue()} # value is microseconds per beat
      when SMPTE_OFFSET
        [firstByte, minute, second, frame, subframe] = @_readMetaData()
        framerate = switch (firstByte & 0x60) >> 5 # extract 2nd+3rd bits for frame rate info. In binary: & 01100000
          when 0 then 24
          when 1 then 25
          when 2 then 29.97
          when 3 then 30 # TODO: test all these via MIDI exports from Logic Pro
        hour = firstByte & 0x1F # last 5 bites, in binary: & 00011111
        {type:'smpte offset', framerate:framerate, hour:hour, minute:minute, second:second, frame:frame, subframe:subframe}

      when TIME_SIGNATURE
        [numerator,denominatorPower] = @_readMetaData() # ignoring "metronome" and "32nds" values
        {type:'time signature', numerator:numerator, denominator:Math.pow(2,denominatorPower)}

      when KEY_SIGNATURE
        [keyValue, scaleValue] = @_readMetaData()
        keyValue = (keyValue ^ 128) - 128 # convert from unsigned byte to signed byte
        key = KEY_VALUE_TO_NAME[keyValue] || keyValue # TODO: interpret key values for minor keys
        scale = switch scaleValue
          when 0 then 'major'
          when 1 then 'minor'
          else scaleValue
        {type:'key signature', key:key, scale:scale}

      when SEQ_SPECIFIC then {type:'sequencer specific', data:@_readMetaData()}
      else console.log "Warning: ignoring unknown meta event type #{type.toString(16)}, with data #{@_readMetaData()}"

    event


  _readSysExEvent: (type) ->
    length = @_readVarLen()
    data = []
    data.push @stream.uInt8() for _ in [0...length] by 1
    # TODO: handle divided events
    {type: "sysex:#{type.toString(16)}", data: data}


  _readChannelEvent: (eventChunkType) ->
    typeMask = (eventChunkType & 0xF0)
    channel = (eventChunkType & 0x0F) + 1

    event = switch typeMask
      when NOTE_ON then @_readNoteOn()
      when NOTE_OFF then @_readNoteOff()
      when NOTE_AFTERTOUCH then {type:'note aftertouch', pitch:@stream.uInt8(), value:@stream.uInt8()}
      when CONTROLLER then {type:'controller', number:@stream.uInt8(), value:@stream.uInt8()}
      when PROGRAM_CHANGE then {type:'program change', number:@stream.uInt8()}
      when CHANNEL_AFTERTOUCH then {type:'channel aftertouch', value:(@stream.uInt8())}
      when PITCH_BEND then {type:'pitch bend', value:(@stream.uInt8()<<7)+@stream.uInt8()}
      else
        # "running status" event using same type and channel of previous event
        runningStatus = true
        @stream.feedByte(eventChunkType) # this will be returned by the next @stream.uInt8() call
        @_readChannelEvent(@prevEventChunkType)

    unless runningStatus
      event.channel = channel if event
      @prevEventChunkType = eventChunkType

    event


  _readNoteOn: ->
    pitch = @stream.uInt8()
    velocity = @stream.uInt8()
    if velocity == 0 # treat like note off with no off velocity
      @_readNoteOff(pitch)
    else
      if @notes[pitch]
        console.log "Warning: ignoring overlapping note on for pitch #{pitch}" # TODO, support this case?
      else
        @notes[pitch] = [velocity,@_currentTime()]
      null # we'll create a "note" event when we see the corresponding note_off


  _readNoteOff: (pitch) ->
    unless pitch # if passed in, this is the pitch of a 0 velocity note on message being treated as a note off
      pitch = @stream.uInt8()
      release = @stream.uInt8() # AKA "off velocity"

    if @notes[pitch]
      [velocity,startTime] = @notes[pitch]
      delete @notes[pitch]
      event = {type:'note', pitch:pitch, velocity:velocity, duration:(@_currentTime() - startTime)}
      event.release = release if release
      event.time = startTime
      event
    else
      console.log "Warning: ignoring note off event for pitch #{pitch} because there was no corresponding note on event"
      null


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
