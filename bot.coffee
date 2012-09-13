Hubot      = require 'hubot'
Fs         = require 'fs'
Path       = require 'path'
HTTP       = require 'http'

Options =
  adapter: "irc"
  alias: '!'
  enableHttpd: true
  name: "Hubot"
  path: "."

adapterPath = Path.resolve __dirname, "node_modules/hubot", "src", "adapters"

robot = Hubot.loadBot adapterPath, Options.adapter, Options.enableHttpd, Options.name

robot.alias = Options.alias

loadScripts = ->
  scriptsPath = Path.resolve ".", "scripts"
  robot.load scriptsPath

  scriptsPath = Path.resolve "src", "scripts"
  robot.load scriptsPath

  scriptsFile = Path.resolve "hubot-scripts.json"
  Path.exists scriptsFile, (exists) =>
    if exists
      Fs.readFile scriptsFile, (err, data) ->
        scripts = JSON.parse data
        scriptsPath = Path.resolve "node_modules", "hubot-scripts", "src", "scripts"
        robot.loadHubotScripts scriptsPath, scripts

robot.adapter.on 'connected', loadScripts

robot.run()

