DashboardParser = require './dashboard_parser'
DashboardProxy = new (require '../cate/cate_proxy')(DashboardParser)

module.exports = (app) ->
  app.get '/api/dashboard', routes.getDashboard

routes =

  getDashboard: (req, res) ->
    dashPromise = DashboardProxy.makeRequest req.query, req.user
    dashPromise.then (dashData) ->
      res.json dashData
      dashData = null
    dashPromise.catch (err) ->
      res.send err.code, err.mssg


