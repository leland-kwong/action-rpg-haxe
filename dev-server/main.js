const express = require('express')
const cors = require('cors')
const bodyParser = require('body-parser')
const fs = require('fs-extra')
const app = express()
const jsonParser = bodyParser.json()

const rootDir = 'bin/external-assets'
const getFullSavePath = (file) => `${rootDir}/${file}`

app.use(cors())

app.post('/save-state', jsonParser, function (req, res) {
  const { body } = req
  const { file, data } = body
  const fullPath = getFullSavePath(file);

  fs.ensureFileSync(fullPath);
  fs.writeFile(fullPath, data)
    .then(() => {
      res.send({
        ok: true
      })
    })
    .catch((err) => {
      res.status(500)
        .send({
          ok: false,
          error: 'error saving file'
        })
      console.error('[save-state error]', err)
    });
})

app.get('/load-state/:keyPath', (req, res) => {
  const { keyPath } = req.params;
  const fullPath = getFullSavePath(keyPath);
  const onError = (err) => {
    res.status(500)
      .send({
        ok: true,
        error: 'error loading file'
      })
    console.error('[load-state error]', err)
  }

  fs.pathExists(fullPath)
    .then((exists) => {
      if (!exists) {
        res.send({
          ok: true,
          data: null
        })
        return;
      }

      fs.readFile(fullPath, 'utf8')
        .then((fileData) => {
          res.send({
            ok: true,
            data: fileData
          })
        })
        .catch(onError)
    });
})

const port = 3000
app.listen(port, (err) => {
  if (err) {
    console.log(err);
  }
  else {
    console.log(`dev server listening on: ${port}`)
  }
})