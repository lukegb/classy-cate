config = require '../config'
# Exam model
Schema = (mongoose = require 'mongoose').Schema
ObjectId = Schema.Types.ObjectId

examSchema = mongoose.Schema
  id:
    type: String
    trim: true
    required: true
    index:
      unique: true
      dropDups: true
  titles: [
    type: String
    trim: true
    required: true
  ]
  classes: [
    type: String
    trim: true
    default: []
  ]
  papers: require './paper_model'

Exam = mongoose.model 'Exam', examSchema
module.exports = Exam