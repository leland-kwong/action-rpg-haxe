const { exec } = require('child_process');
const chokidar = require('chokidar');
const fs = require('fs-extra');
const argv = require('minimist')(process.argv.slice(2));
const { 
  port = 6001,
  env = 'development',
  compileFile = 'build.hxml'
} = argv;

const compileLogger = require('debug')('watcher.compile');
const fileClearedStates = new Map();
const logToDisk = async (file, label, result, logFn) => {
  try {

    const formattedLabel = (
      /err/.test(label) 
      ? `=== ${label} ===` 
      : label
    ).toUpperCase() + ` -- [${env}]`;
    const formattedResult = `\n${formattedLabel}\n${new Date()}\n${result}\n`;
    const logFile = `./.logs/${file}`;

    logFn(formattedResult);
    await fs.ensureDir('./.logs');

    if (!fileClearedStates.has(logFile)) {
      fileClearedStates.set(logFile, true);
      // truncate file for new sessions to 
      // prevent log files from growing too large
      await fs.writeFile(logFile, '');
    }

    await fs.appendFile(
      logFile, 
      formattedResult);

  } catch (err) {

    console.dir('=== log to disk error ===', err);

  }
}

const compile = (buildFile) => {
  logToDisk('build.txt', `compiling... ${buildFile}`, '', compileLogger);

  const flags = env === 'development' 
    ? '-D debugMode'
    : '-D production';
  const cmd = `haxe ${flags} ${buildFile} --connect ${port}`;

  exec(cmd, (err, stdout, stderr) => {
    if (err) {

      logToDisk(
        'build.txt', 'compile error', err, compileLogger);

    } else if (stderr) {

      logToDisk(
        'build.txt', 'compile stderr', stderr, compileLogger);
      
    } else {

      logToDisk(
        'build.txt', 'compile success', '', compileLogger);

    }
  });
}

const filenameWithoutExtension = (filePath) => 
  filePath.split('/').slice(-1)[0].replace(/\.[^]+/g, '');

exec(`haxe --wait ${port}`, (err, stdout, stderr) => {
  if (err) {
    //some err occurred
    console.error(err)
  } else {
    // the *entire* stdout and stderr (buffered)
    console.log('server ready')
  }
});

let pending = null;

const rebuild = (eventType, filename, options) => {
  const { delay } = options;

  if (options.verbose) {
    console.log(`${ filename } changed`)
  }

  clearTimeout(pending)
  pending = setTimeout(() => {
    compile(compileFile)
  }, delay)
}

const startCompileWatcher = (options = {}) => {
  chokidar.watch([
    './Main.hx',
    './src/**/*.hx',
    './src/res/**/*.*',
  ], {
    // this prevents locking up the file system for other windows applications
    usePolling: true,
  }).on('all', (event, path) => {
    rebuild(event, path, options);
  });
}

function startReplWatcher() {
  chokidar.watch('./Repl.hx').on('all', () => {
    exec(`haxe repl-build.hxml --connect ${port}`, (err, stdout, stderr) => {
      if (err) {
        console.log('\n==== repl build error ===='.toUpperCase());
        console.error(err);
        return;
      }

      if (stderr) {
        console.log('\n==== repl build stderror ===='.toUpperCase());
        console.error(stderr);
        return;
      }

      console.log('\n==== repl build success ===='.toUpperCase());
      console.log(stdout);
      delete require.cache[require.resolve('./temp/repl-haxe.js')];
      try {
        require('./temp/repl-haxe.js');
      } catch (err) {
        console.error('repl build error', err);
      }
    });
  });
}

startReplWatcher({});
startCompileWatcher({
  delay: 1000,
  verbose: true
});
