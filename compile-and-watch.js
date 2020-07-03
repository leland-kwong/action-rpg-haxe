const { exec } = require('child_process');
const chokidar = require('chokidar');
const fs = require('fs');
const [, , port] = process.argv;
require('./dev-server/main');

if (port === undefined) {
  throw new Error('port must be provided');
}

const compile = (buildFile) => {
  console.log(`compiling ${buildFile}`);

  exec(`haxe ${buildFile} --connect ${port}`, (err, stdout, stderr) => {
    if (err) {
      //some err occurred
      console.error(err)
    } else {
      // the *entire* stdout and stderr (buffered)
      console.log(`build success ${buildFile}`)
    }
  });
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

compileFile = 'build.js.hxml'
compile(compileFile)

let pending = null;

const rebuild = (eventType, filename) => {
  const isHaxeFile = /\.hx$/.test(filename);
  const isSrcDir = filename.indexOf('src') === 0;

  if (!isHaxeFile && !isSrcDir) {
    return;
  }

  console.log(`${ filename } changed`)
  clearTimeout(pending)
  pending = setTimeout(() => {
    compile(compileFile)
  }, 500)
}

chokidar.watch('.').on('all', (event, path) => {
  rebuild(event, path);
});

