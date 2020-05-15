const { exec } = require('child_process');
const fs = require('fs');

const compile = (buildFile) => {
  exec(`haxe ${buildFile} --connect 6000`, (err, stdout, stderr) => {
    if (err) {
      //some err occurred
      console.error(err)
    } else {
    // the *entire* stdout and stderr (buffered)
      console.log('build success')
    }
  });
}

exec('haxe -v --wait 6000', (err, stdout, stderr) => {
  if (err) {
    //some err occurred
    console.error(err)
  } else {
  // the *entire* stdout and stderr (buffered)
    console.log('build success')
  }
});

console.log('running initial compile')
compileFile = 'build.hxml'
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