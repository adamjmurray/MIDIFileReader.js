DEBUG = process.env.DEBUG

filepath = process.argv[2]
throw 'MIDI input file path is required' unless filepath

midi = new MIDIFileReader filepath, NodeFileReader
midi.read ->
  console.log "Tracks:"
  console.log JSON.stringify(midi.tracks, null, 2)
  console.log "MIDI format type: #{midi.formatType}"
  console.log "Number of tracks: #{midi.numTracks}"
  console.log "Time division: #{midi.timeDiv}"
