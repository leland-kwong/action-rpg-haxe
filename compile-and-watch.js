const { exec } = require('child_process');
const chokidar = require('chokidar');
const fs = require('fs-extra');
const [, , port] = process.argv;
require('./dev-server/main');

if (port === undefined) {
  throw new Error('port must be provided');
}

const compile = (buildFile) => {
  console.log(`compiling ${buildFile}`);

  exec(`haxe ${buildFile} --connect ${port}`, (err, stdout, stderr) => {
    if (err) {
      console.error(err)
    } else if (stderr) {
      console.error(stderr)
    } else {
      console.log(`build success ${buildFile}`)
    }
  });
}

const filenameWithoutExtension = (filePath) => 
  filePath.split('/').slice(-1)[0].replace(/\.[^]+/g, '');

const exportDir = (filename) => 
  `./src/art/aseprite_exports/${filenameWithoutExtension(filename)}`

const cleanupAsepriteExport = async (exportDir) => {
  return fs.remove(exportDir);
}

const asepriteExport = async (fileEvent, filename, exportDir, exportFile) => {
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
    exec(`${asepriteExecutable} ${asepriteArgs}`, (err, stdout, stderr) => {
      if (err) {
        console.error(err)
      } else if (stderr) {
        console.error(stderr)
      } else {
        console.log(`[aseprite success] exported \`${filename}\` to \`${exportFullPath}\``)
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

const rebuild = (eventType, filename, options = {}) => {
  const isHaxeFile = /\.hx$/.test(filename);
  const isSrcDir = filename.indexOf('src') === 0;
  const isVimFile = filename.endsWith('swp') 
    || filename.endsWith('save');

  if (isVimFile || (!isHaxeFile && !isSrcDir)) {
    return;
  }

  if (options.verbose) {
    console.log(`${ filename } changed`)
  }
  clearTimeout(pending)
  pending = setTimeout(() => {
    compile(compileFile)
  }, 1000)
}

const startCompileWatcher = () => {
  chokidar.watch('.', {
    // this prevents locking up the file system for other windows applications
    usePolling: true,
  }).on('all', (event, path) => {
    rebuild(event, path);
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
          console.error(err)
        } else if (stderr) {
          console.error(stderr)
        } else {
          console.log(`[tiledExport][export success] \`${path}\` to \`${outputPath}\``);
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

startCompileWatcher();

startAsepriteWatcher({
  // verbose: true,
  animationFilePattern: /_animation$/
});

startTiledWatcher({
  verbose: true
});
