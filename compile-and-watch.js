const { exec } = require('child_process');
const fs = require('fs');

const compile = (file) => {
  exec(`haxe --connect 6000 ${file}`, (err, stdout, stderr) => {
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
compileFile = 'compile.hxml'
compile(compileFile)

fs.watch('Main.hx', (eventType, filename) => {
  console.log(filename)
  if (filename.indexOf('.hx') === -1) {
    console.log(filename)
    return
  }
  compile(compileFile)
})