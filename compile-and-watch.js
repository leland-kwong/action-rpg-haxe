const { exec } = require('child_process');
const chokidar = require('chokidar');
const fs = require('fs-extra');
const argv = require('minimist')(process.argv.slice(2));
const { 
  port = 6001,
  env = 'development',
  compileFile = 'build.hxml'
} = argv;

require('./dev-server/main');

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

const asepriteExportDir = './src/art/aseprite_exports';

const filenameWithoutExtension = (filePath) => 
  filePath.split('/').slice(-1)[0].replace(/\.[^]+/g, '');

const makeExportDir = (filename) => 
  `${asepriteExportDir}/${filenameWithoutExtension(filename)}`

const cleanupAsepriteExport = async (exportDir) => {
  return fs.remove(exportDir);
}

const asepriteLogger = require('debug')('watcher.aseprite');
const asepriteExport = async (
  fileEvent, exportDir, asepriteArgs) => {
  try {
    console.log(`[aseprite] cleaning export directory \`${exportDir}\`...`);
    await cleanupAsepriteExport(exportDir);
    console.log(`[aseprite success], removed export directory \`${exportDir}\``);

    if (fileEvent == 'unlink') {
      // only trigger the directory cleanup
      return;
    }

    await fs.ensureDir(exportDir);

    const asepriteExecutable = '\'/mnt/c/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe\'';
    const cmd = `${asepriteExecutable} ${asepriteArgs}`;
    exec(cmd, (err, stdout, stderr) => {
      if (err) {

        logToDisk(
          'build.txt', 'aseprite error', err, asepriteLogger);

      } else if (stderr) {
        
        logToDisk(
          'build.txt', 'aseprite stderr', stderr, asepriteLogger);

      } else {

        logToDisk(
          'build.txt', 'aseprite export success', '', asepriteLogger);

      }
    });

  } catch (err) {

    logToDisk(
      'build.txt', 'aseprite error', err, asepriteLogger);

  }
}

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

// [Aseprite](https://www.aseprite.org/)
const startAsepriteWatcher = (options) => {
  const debounceStates = new Map();

  const handleAesepriteExport = (eventType, path) => {
    if (options.verbose) {
      console.log(`[aseprite watch][${eventType}] \`${path}\``);
    }

    const previousPendingBuild = debounceStates.get(path);
    clearTimeout(previousPendingBuild);

    const triggerBuild = () => {
      // filenames with the pattern {my_file}_animation.aseprite
      const isAnimationFile = options.animationFilePattern.test(filenameWithoutExtension(path));
      const filePath = isAnimationFile 
        ? '{tag}-{frame}.png' 
        : '{slice}.png';
      console.log('[filename]', path);
      const exportDir =  makeExportDir(path);
      const exportFullPath = `${exportDir}/${filePath}`;
      const asepriteArgs = `-b ${path} --save-as ${exportFullPath}`;
      asepriteExport(eventType, exportDir, asepriteArgs);
    }
    const newPendingBuild = setTimeout(triggerBuild, 300);
    debounceStates.set(path, newPendingBuild);
  }

  chokidar.watch('./src/art/*.aseprite', {
    usePolling: true,
  }).on('all', handleAesepriteExport);
}

const startTexturePackerWatcher = (options = {}) => {
  const tpLogger = require('debug')('watcher.texturePacker');
  let pending = 0; 
  const {
    destination,
    sourceFile
  } = options;
  const handleTexturePackerExport = (eventType) => {
    clearTimeout(pending)

    pending = setTimeout(() => {
      const tpExecutable = '\'/mnt/c/Program Files/CodeAndWeb/TexturePacker/bin/TexturePacker.exe\''; 
      const cmd = `${tpExecutable} --sheet ${destination} ${sourceFile}`; 
      const name = 'texturepacker'

      exec(cmd, (err, stdout, stderr) => {
        if (err) {

          logToDisk(
            `build.txt`, `${name} error`, err, tpLogger);

        } else if (stderr) {

          logToDisk(
            `build.txt`, `${name} stderr`, stderr, tpLogger);

        } else {

          const msg = `\`${sourceFile}\` to \`${destination}\``;
          logToDisk(
            `build.txt`, `${name} success`, msg, tpLogger);

        }
      });
    }, 500);
  }

  chokidar.watch([
    './src/art/*.tps',
    asepriteExportDir,
  ], {
    usePolling: true,
  }).on('all', handleTexturePackerExport);
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
  delay: 1000
});
startAsepriteWatcher({
  // verbose: true,
  animationFilePattern: /_animation$/
});
startTexturePackerWatcher({
  sourceFile: './src/art/sprite_sheet.tps',
  destination: './src/res/sprite_sheet.png'
});
startTexturePackerWatcher({
  sourceFile: './src/art/sprite_sheet_ui_cursor.tps',
  destination: './src/res/sprite_sheet_ui_cursor.png'
});
