const fs = require('fs-extra');
const chokidar = require('chokidar');
const path = require('path');
const { exec } = require('child_process');
const asepriteExecutable = '\'/mnt/c/Program Files (x86)/Steam/steamapps/common/Aseprite/Aseprite.exe\'';
const asepriteExportDir = './src/art/aseprite_exports';
const asepriteExportLayerCmd = ({
  layer, 
  file,
  exportDir
}) => [
  asepriteExecutable,
  '-b',
  `--layer "${layer}"`,
  file,
  // NOTE:
  // If we use `{layer}` as a part of the filename, aseprite will
  // ignore the `--layer` option.
  `--save-as ${exportDir}/{tag}-{frame}--${layer}.png`
].join(' ');

function getAsepriteLayers(file) {
  const cmd = 
  `${asepriteExecutable} -b --list-layers ${file}`;

  return new Promise((resolve, reject) => {
    exec(cmd, (err, stdout, stderr) => {
      const error = err || stderr;

      if (error) {
        reject(error);
        return;
      }

      resolve(stdout.split('\n').map(l => l.trim()));
    });
  });
}

const layersToExport = ['main', 'shadow', 'light_source'];
const requiredLayers = ['main'];

async function run(event, file) {
  try {
    console.log(`[aseprite animation ${event}] ${file}`);
    const basename = path.basename(file, '.aseprite');
    const fullExportDir = `${asepriteExportDir}/${basename}`;
    await fs.remove(fullExportDir);

    if (event === 'unlink') {
      return;
    }

    const layerNames = await getAsepriteLayers(
      file);

    requiredLayers.forEach((layer) => {
      if (!layerNames.includes(layer)) {
        throw new Error(
          `animation \`${file}\` missing layer ${layer}`);
      }
    });

    const commandConfigs = layerNames.filter((layer) => {
      return layersToExport.includes(layer);
    }).map((layer) => {
      return {
        layer,
        file,
        exportDir: fullExportDir
      };
    });

    function execCmd(config) {
      const { layer } = config; 
      const cmd = asepriteExportLayerCmd(config);

      exec(cmd, (err, stdout, stderr) => {
        if (err) {

          console.error('error: ', err);

        } else if (stderr) {

          console.error('stderr: ', stderr);

        } else if (stdout) {

          console.log('stdout: ', stdout);

        } else {

          console.log(
            `[aseprite animation] exported layer \`${layer}\``);

        }
      });
    }
    commandConfigs.forEach(execCmd);
  } catch (err) {
    console.error('run error', err);
  }
}

module.exports = (watchPattern) => {
  chokidar.watch(watchPattern, {
    usePolling: true
  }).on('all', run);
}
