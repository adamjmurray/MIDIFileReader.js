# Simulate the console with the Max window, for debugging and interoperability with Node.js
@console =
  log: (msg...) -> post(msg+"\n")
  error: (msg...) -> error(msg+"\n")


read = (filepath) ->
  midi = new MIDIFileReader(new MaxFileStream(filepath))
  midi.read ->
    console.log "Tracks:"
    console.log JSON.stringify(midi.tracks, null, 2)
    console.log "MIDI format type: #{midi.formatType}"
    console.log "Number of tracks: #{midi.numTracks}"
    console.log "Time division: #{midi.timeDiv}"


console.log "Reloaded on " + new Date