PROJECT = 'MIDIFileReader'
VERSION = '0.1'

BASE_DIR = __dirname
BUILD_DIR = "#{BASE_DIR}/build"
SRC_DIR = "#{BASE_DIR}/src"
TEST_DIR = "#{BASE_DIR}/test"
DIST_DIR = "#{BASE_DIR}/dist"

src_for = (name) -> "#{SRC_DIR}/#{name}.coffee"

BASE_SRC_FILES = (src_for name for name in [
  'NodeFileReader'
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

spawn = require('child_process').spawn

exec = (cmd, args=[], options={}, callback) ->
  desc = "#{cmd} #{args.join(' ')}"
  desc = "cd #{options.process?.cwd} && #{desc}" if options.process?.cwd?
  console.log "\n#{desc}"
  console.log options.message if options.message
  process = spawn(cmd, args, options.process)
  process.stdout.on 'data', (data)-> console.log(data.toString())
  process.stderr.on 'data', (data)-> console.log(data.toString())
  process.on 'exit', (code)->
    if code == 0
      console.log "SUCCESS" unless options.suppressStatus
      callback() if callback
    else
      console.log "exited with error code #{code}"


task 'clean', 'remove build artifacts', ->
  exec 'rm', ['-rf', OUT_FILE, DIST_DIR]


task 'dev', 'watch the source files and rebuild automatically while developing', ->
  exec 'coffee', ['--watch'].concat(COFFEE_ARGS), {message: "\nWatching files... use ctrl+C to exit.\n"}


task 'build', 'build the app (debug version)', ->
  exec 'coffee', COFFEE_ARGS


task 'validate', 'validate syntax', ->
  for file in SRC_FILES
    unless file.match /main\.coffee$/ # this will always fail because it depends on the other files
      exec 'coffee', [file], {suppressStatus: true}


task 'test', 'run the unit tests', ->
  exec 'coffee', ['--compile', '--join', TEST_OUT_FILE].concat(TEST_FILES), {}, ->
    exec 'jasmine-node', ['--coffee', '--matchall', '--verbose', TEST_DIR]


task 'release', 'build the app (release version, minified)', ->
  exec 'coffee', COFFEE_ARGS, suppressStatus:true, ->
    exec 'uglifyjs', ['-nmf', '--overwrite', OUT_FILE], {}, ->
      console.log '\nDone building the release vesion.\n'


task 'dist', 'package the app for distribution', ->
  opts = {suppressStatus: true}
  project = "#{PROJECT}-#{VERSION}"
  archive = "#{project}.zip"
  distFolder = "#{DIST_DIR}/#{project}"
  exec 'rm', ['-rf', DIST_DIR], opts, ->
    exec 'mkdir', ['-p', "#{distFolder}/#{PROJECT}"], opts, ->
      exec 'zip', ['-qlr', '-9', archive, project], {process:{cwd:DIST_DIR}}
