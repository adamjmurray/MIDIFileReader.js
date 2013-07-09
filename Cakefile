PROJECT = 'MIDIFileReader'
VERSION = '0.1'

BASE_DIR = __dirname
BUILD_DIR = "#{BASE_DIR}/build"
SRC_DIR = "#{BASE_DIR}/src"
TEST_DIR = "#{BASE_DIR}/test"
DIST_DIR = "#{BASE_DIR}/dist"

src_for = (name) -> "#{SRC_DIR}/#{name}.coffee"

BASE_SRC_FILES = (src_for name for name in [
  'NodeFileStream'
  'MIDIFileReader'
])
SRC_FILES = BASE_SRC_FILES.concat src_for('main')
OUT_FILE = "#{BUILD_DIR}/#{PROJECT}.js"

COFFEE_ARGS = [
  '--bare'
  '--join'
  OUT_FILE
  '--compile'
  'license.txt'
].concat SRC_FILES

TEST_FILES = BASE_SRC_FILES.concat(src_for 'exports')
TEST_OUT_FILE = "#{TEST_DIR}/#{PROJECT}.js"

child_process = require('child_process')
require('colors')

exec = (cmd, callback) ->
  console.log cmd.blue
  child_process.exec cmd, (error, stdout, stderr) ->
    console.log stdout if stdout
    console.error stderr.red if stderr
    throw error if error
    console.log 'Success'.green
    callback() if callback


task 'clean', 'remove build artifacts', ->
  exec "rm -rf #{OUT_FILE} #{DIST_DIR}"


# TODO: this needs to use child_process.spawn
#task 'dev', 'watch the source files and rebuild automatically while developing', ->
#  exec 'coffee', ['--watch'].concat(COFFEE_ARGS), {message: "\nWatching files... use ctrl+C to exit.\n"}


task 'build', 'build the app (debug version)', ->
  exec "coffee #{COFFEE_ARGS.join(' ')}"


task 'validate', 'validate syntax', ->
  for file in SRC_FILES
    unless file.match /main\.coffee$/ # this will always fail because it depends on the other files
      exec "coffee #{file}"


task 'test', 'run the unit tests', ->
  exec "coffee --compile --join #{TEST_OUT_FILE} #{TEST_FILES.join(' ')}", ->
    exec "jasmine-node --coffee --matchall --verbose --captureExceptions #{TEST_DIR}"


#task 'release', 'build the app (release version, minified)', ->
#  exec "coffee #{COFFEE_ARGS.join(' ')}", ->
#    exec "node_modules/.bin/uglifyjs -nmf --overwrite #{OUT_FILE}", ->
#      console.log '\nDone building the release vesion.\n'


#task 'dist', 'package the app for distribution', ->
#  opts = {suppressStatus: true}
#  project = "#{PROJECT}-#{VERSION}"
#  archive = "#{project}.zip"
#  distFolder = "#{DIST_DIR}/#{project}"
#  exec 'rm', ['-rf', DIST_DIR], opts, ->
#    exec 'mkdir', ['-p', "#{distFolder}/#{PROJECT}"], opts, ->
#      exec 'zip', ['-qlr', '-9', archive, project], {process:{cwd:DIST_DIR}}
