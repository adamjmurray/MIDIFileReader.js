MIDIFileReader.js
=================

This will be a lightweight library to read the Standard MIDI File (SMF) format.

This is very much an experimental work in progress and not ready yet. So far it can read the MIDI file metadata out of the file header.

Requires Node.js.

Currently I run it like so:

        cake build
        node build/MIDIFileReader.js {MIDI_file_path}
