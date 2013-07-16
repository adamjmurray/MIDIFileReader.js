# Simulate the console with the Max window, for debugging and interoperability with Node.js
@console =
  log: (msg...) -> post(msg+"\n")
  error: (msg...) -> error(msg+"\n")

TICKS_PER_BEAT = 480
_ = '' # no-op value

dictName = jsarguments[1]
if dictName
  dict = new Dict(dictName)
else
  console.error 'Missing argument: Dict name'


read = (filepath) ->
  midi = new MIDIFileReader(new MaxFileStream(filepath))
  midi.read ->
    #console.log JSON.stringify(midi.tracks, null, 2)
    if dict
      dict.clear()
      for track,index in midi.tracks
        trackName = "track#{index+1}"
        timeline = new Dict("#{dictName}.#{trackName}")
        timeline.clear()

        for time,events of track
          data = []
          for e in events
            switch e.type
              when 'note'               then data.push 'note', e.pitch, e.velocity, e.duration*TICKS_PER_BEAT
              when 'controller'         then data.push 'cc', e.number, e.value, _
              when 'channel aftertouch' then data.push 'aftertouch', e.value, _, _
              when 'pitch bend'         then data.push 'pitchbend', e.value, _, _

          # TODO: optional quantization?
          timeline.set(time*TICKS_PER_BEAT, data) if data.length > 0

        dict.set(trackName, timeline)


console.log "Reloaded on " + new Date