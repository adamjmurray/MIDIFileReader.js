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

    it "reads a simple 1 track (format 0) MIDI file", ->
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
                'off velocity': 95,
                time: 0,
                channel: 1
              },
              {
                type: 'note',
                pitch: 62,
                velocity: 95,
                duration: 1,
                'off velocity': 95,
                time: 1,
                channel: 1
              },
              {
                type: 'note',
                pitch: 64,
                velocity: 95,
                duration: 1,
                'off velocity': 95,
                time: 2,
                channel: 1
              }
            ]
          }
        ]