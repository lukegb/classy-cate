$q = require 'q'

dashboard = require './dashboard'
exercises = require './exercises'
grades    = require './grades'
notes     = require './notes'
givens    = require './givens'

module.exports = (app) ->

  app.get '/api/dashboard', dashboard.getDashboard
  app.get '/api/exercises', exercises.getExercises
  app.get '/api/grades', grades.getGrades
  app.get '/api/notes', notes.getNotes
  app.get '/api/givens', givens.getGivens
