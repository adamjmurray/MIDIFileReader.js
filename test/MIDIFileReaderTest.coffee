{MIDIFileReader,NodeFileStream} = require "#{__dirname}/MIDIFileReader.js"

describe 'MIDIController', ->

  read = (file, expectations) ->
    reader = new MIDIFileReader( new NodeFileStream("#{__dirname}/files/#{file}") )
    doneReading = false
    runs ->
      reader.read ->
        expectations(reader)
        doneReading = true
    waitsFor ->
      doneReading == true



  describe 'read', ->

    it "reads a simple single-track (format 0) MIDI file", ->
      read 'simple.mid', (midi) ->
        expect( midi.formatType ).toBe 0
        expect( midi.timeDiv ).toBe 480
        expect( midi.numTracks ).toBe 1
        expect( midi.tracks ).toEqual [
          {
            number: 1,
            events: [
              {
                type: 'note',
                pitch: 60,
                velocity: 95,
                duration: 1,
                time: 0,
                channel: 1
              },
              {
                type: 'note',
                pitch: 62,
                velocity: 95,
                duration: 1,
                time: 1,
                channel: 1
              },
              {
                type: 'note',
                pitch: 64,
                velocity: 95,
                duration: 1,
                time: 2,
                channel: 1
              }
            ]
          }
        ]


    it "reads a multitrack (format 1) MIDI file", ->
      read 'multitrack.mid', (midi) ->
        expect( midi.formatType ).toBe 1
        expect( midi.timeDiv ).toBe 480
        expect( midi.numTracks ).toBe 3
        expect( midi.tracks ).toEqual [
          {
            "number": 1,
            "events": [
              {
                "type": "time signature",
                "numerator": 4,
                "denominator": 4,
                "time": 0
              },
              {
                "type": "key signature",
                "key": "D",
                "scale": "major",
                "time": 0
              },
              {
                "type": "marker",
                "text": "Marker 1",
                "time": 0
              },
              {
                "type": "smpte offset",
                "framerate": 30,
                "hour": 1,
                "minute": 0,
                "second": 0,
                "frame": 0,
                "subframe": 0,
                "time": 0
              },
              {
                "type": "tempo",
                "bpm": 120,
                "time": 0
              },
              {
                "type": "marker",
                "text": "Marker 2",
                "time": 4
              }
            ]
          },
          {
            "number": 2,
            "events": [
              {
                "type": "sequence name",
                "text": "track 1",
                "time": 0
              },
              {
                "type": "instrument name",
                "text": "Instrument 1",
                "time": 0
              },
              {
                "type": "note",
                "pitch": 67,
                "velocity": 90,
                "duration": 0.25,
                "time": 0,
                "channel": 1
              },
              {
                "type": "note",
                "pitch": 64,
                "velocity": 100,
                "duration": 0.5,
                "time": 0,
                "channel": 1
              },
              {
                "type": "note",
                "pitch": 60,
                "velocity": 127,
                "duration": 1,
                "time": 0,
                "channel": 1
              },
              {
                "type": "note",
                "pitch": 60,
                "velocity": 80,
                "duration": 2,
                "time": 4,
                "channel": 1
              }
            ]
          },
          {
            "number": 3,
            "events": [
              {
                "type": "sequence name",
                "text": "track 2",
                "time": 0
              },
              {
                "type": "instrument name",
                "text": "Instrument 2",
                "time": 0
              },
              {
                "type": "note",
                "pitch": 48,
                "velocity": 70,
                "duration": 8,
                "time": 0,
                "channel": 1
              }
            ]
          }
        ]
