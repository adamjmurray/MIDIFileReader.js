# Simulate the console with the Max window, for debugging and interoperability with Node.js
@console =
  log: (msg...) -> post(msg+"\n")
  error: (msg...) -> error(msg+"\n")

dictName = jsarguments[1]
if dictName
  dict = new Dict(dictName)
else
  console.error 'Missing argument: Dict name'

TICKS_PER_BEAT = 480

read = (filepath) ->
  midi = new MIDIFileReader(new MaxFileStream(filepath))
  midi.read ->
    #console.log JSON.stringify(midi.tracks, null, 2)
    if dict
      dict.clear()
      for track in midi.tracks
        trackDictName = "track#{track.number}"
        timeline = new Dict("#{dictName}.#{trackDictName}")
        timeline.clear()

        for time,events of track.events
          data = []
          for e in events
            switch e.type
              when 'note' then data.push 'note', e.pitch, e.velocity, e.duration*TICKS_PER_BEAT
              when 'controller' then data.push 'cc', e.number, e.value, ''
              when 'channel aftertouch' then data.push 'aftertouch', e.value, '', ''
              when 'pitch bend' then data.push 'pitchbend', e.value, '', ''

          timeline.set(time*TICKS_PER_BEAT, data) if data.length > 0

        dict.set(trackDictName, timeline)


console.log "Reloaded on " + new Date