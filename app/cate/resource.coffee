cheerio = require 'cheerio'
request = require 'request'

class CateResource

  constructor: (@$, @$page) ->
    @data = {}
    do @parse

  parse: ->
    throw new Error 'Override the parse method!!'

  # GET handler for requesting information
  @get: (req, res) ->
    options =
      url: @url req
      auth:
        user: req.user.user
        pass: req.user.pass
        sendImmediately: true
    request options, (err, data, body) =>
      $ = cheerio.load body, {
        xmlMode: true
        lowerCaseTags: true
      }
      cate_res = new @ $, $ 'body'
      res.json cate_res.data

module.exports = CateResource
