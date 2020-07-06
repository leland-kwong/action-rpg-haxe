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
  }, 500)
}

const startCompileWatcher = () => {
  chokidar.watch('.', {
    // this prevents locking up the file system for other windows applications
    usePolling: true,
  }).on('all', (event, path) => {
    rebuild(event, path);
  });
}

const startAsepriteWatcher = (options) => {
  const handleAesepriteExport = (ev, path) => {
    const isAsepriteFile = path.endsWith('.aseprite');

    if (!isAsepriteFile) {
      return;
    }

    // filenames with the pattern {my_file}_animation.aseprite
    const isAnimationDir = options.animationFilePattern.test(filenameWithoutExtension(path));
    const filePath = isAnimationDir ? '{tag}-{frame}.png' : '{slice}.png';
    asepriteExport(ev, path, exportDir(path), filePath);
  }

  chokidar.watch('./src/art', {
    usePolling: true,
  }).on('all', handleAesepriteExport);
}

startCompileWatcher();
startAsepriteWatcher({
  animationFilePattern: /_animation$/
});
