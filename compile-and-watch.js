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

const exportDir = (filename) => 
  `${asepriteExportDir}/${filenameWithoutExtension(filename)}`

const cleanupAsepriteExport = async (exportDir) => {
  return fs.remove(exportDir);
}

const asepriteLogger = require('debug')('watcher.aseprite');
const asepriteExport = async (
  fileEvent, filename, exportDir, exportFile
) => {
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
    const exportFullPath = `${exportDir}/${exportFile}`;
    const asepriteArgs = `-b ${filename} --save-as ${exportFullPath}`;

    console.log(`[aseprite] exporting file \`${filename}\`...`);
    const cmd = `${asepriteExecutable} ${asepriteArgs}`;
    exec(cmd, (err, stdout, stderr) => {
      if (err) {

        logToDisk(
          'build.txt', 'aseprite error', err, asepriteLogger);

      } else if (stderr) {
        
        logToDisk(
          'build.txt', 'aseprite stderr', stderr, asepriteLogger);

      } else {

        const msg = `exported \`${filename}\` to \`${exportFullPath}\``;
        logToDisk(
          'build.txt', 'aseprite success', msg, asepriteLogger);

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
      const filePath = isAnimationFile ? '{tag}-{frame}.png' : '{slice}.png';
      asepriteExport(eventType, path, exportDir(path), filePath);
    }
    const newPendingBuild = setTimeout(triggerBuild, 300);
    debounceStates.set(path, newPendingBuild);
  }

  chokidar.watch('./src/art/*.aseprite', {
    usePolling: true,
  }).on('all', handleAesepriteExport);
}

// [Tiled App](https://www.mapeditor.org/)
const startTiledWatcher = (options = {}) => {
  const tiledLogger = require('debug')('watcher.tiled');
  const debounceStates = new Map();
  const handleTiledExport = (eventType, path) => {
    const previousPending = debounceStates.get(path);
    clearTimeout(previousPending);

    if (options.verbose) {
      console.log(`[tiledExport watch][${eventType}] \`${path}\``);
    }

    const triggerExport = () => {
      const tiledExecutable = '\'/mnt/c/Program\ Files/Tiled/tiled.exe\''; 
      // outputs file type based on file extension
      console.log(`[tiledExport][export start] \`${path}\``);
      const outputPath = path.replace(/\.tmx/, '.json');
      const name = 'tiled';

      // [Tiled cli export instructions](https://github.com/bjorn/tiled/issues/903)
      exec(`${tiledExecutable} --export-map ${path} ${outputPath}`, (err, stdout, stderr) => {
        if (err) {
          logToDisk(
            `build.txt`, `${name} error`, err, tiledLogger);
        } else if (stderr) {
          logToDisk(
            `build.txt`, `${name} stderr`, stderr, tiledLogger);
        } else {
          const msg = `\`${path}\` to \`${outputPath}\``;
          logToDisk(
            `build.txt`, `${name} success`, msg, tiledLogger);
        }
      });
    }
    const newPending = setTimeout(triggerExport, 300);
    debounceStates.set(path, newPending);
  }

  chokidar.watch('./src/res/*.tmx', {
    usePolling: true,
  }).on('all', handleTiledExport);
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
      console.log('[tiledExport]', eventType, sourceFile);
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
startTiledWatcher({
  verbose: true
});
startTexturePackerWatcher({
  sourceFile: './src/art/sprite_sheet.tps',
  destination: './src/res/sprite_sheet.png'
});
startTexturePackerWatcher({
  sourceFile: './src/art/sprite_sheet_ui_cursor.tps',
  destination: './src/res/sprite_sheet_ui_cursor.png'
});
