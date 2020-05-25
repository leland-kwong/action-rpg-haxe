const { exec } = require('child_process');
const fs = require('fs');
const [, , port] = process.argv;

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
      console.log('build success')
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
  if (filename.indexOf('.hx') === -1) {
    return
  }

  console.log(`${ filename } changed`)
  clearTimeout(pending)
  pending = setTimeout(() => {
    compile(compileFile)
  }, 50)
}

fs.watch('Main.hx', rebuild);
fs.watch('src', rebuild)