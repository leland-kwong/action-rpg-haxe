const { exec } = require('child_process');
const chokidar = require('chokidar');
const fs = require('fs-extra');
const [, , port] = process.argv;
require('./dev-server/main');

if (port === undefined) {
  throw new Error('port must be provided');
}

const compileLogger = require('debug')('watcher.compile');
const compile = (buildFile) => {
  console.log(`compiling ${buildFile}`);

  const flags = '-D debugMode';
  const cmd = `haxe ${flags} ${buildFile} --connect ${port}`;
  exec(cmd, (err, stdout, stderr) => {
    if (err) {
      compileLogger(err)
    } else if (stderr) {
      compileLogger(stderr)
    } else {
      compileLogger(`build success ${buildFile}`)
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
        asepriteLogger(err)
      } else if (stderr) {
        asepriteLogger(stderr)
      } else {
        asepriteLogger(`[aseprite success] exported \`${filename}\` to \`${exportFullPath}\``)
      }
    });
  } catch (err) {
    console.error('[aseprite export error]', err)
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

compileFile = 'build.hxml'
compile(compileFile)

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
    './**/*.hx',
    './src/res',
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
      console.log(`[tiledExport][export start] \`${path}\``);
      const tiledExecutable = '\'/mnt/c/Program\ Files/Tiled/tiled.exe\''; 
      // outputs file type based on file extension
      const outputPath = path.replace(/\.tmx/, '.json');

      // [Tiled cli export instructions](https://github.com/bjorn/tiled/issues/903)
      exec(`${tiledExecutable} --export-map ${path} ${outputPath}`, (err, stdout, stderr) => {
        if (err) {
          tiledLogger(err)
        } else if (stderr) {
          tiledLogger(stderr)
        } else {
          tiledLogger(`[tiledExport][export success] \`${path}\` to \`${outputPath}\``);
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
      console.log('[tiledExport]', eventType, sourceFile);
      exec(cmd, (err, stdout, stderr) => {
        if (err) {
          tpLogger(err)
        } else if (stderr) {
          tpLogger(stderr)
        } else {
          tpLogger(`[texturePackerExport][export success] \`${sourceFile}\` to \`${destination}\``);
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

startCompileWatcher({
  delay: 1500
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
