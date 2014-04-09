classy = angular.module 'classy'

classy.factory 'Exercise', ->
  class Exercise
    constructor: (data) ->
      angular.extend @, data
      @start = new Date @start
      @end = new Date @end

classy.factory 'Module', (Exercise) ->
  class Module
    constructor: (data, @exercises = []) ->
      angular.extend @, data
      @exercises = (new Exercise e for e in @exercises)


classy.factory 'Exercises', (CateResource, Module, $rootScope, $q) ->
  class Exercises extends CateResource('/api/exercises')
    constructor: (data) ->
      super data
      @modules = (new Module m for m in @modules)
    @get: (params) ->
      super @initParams params
    @initParams: (state) ->
      params =
        year: $rootScope.current_year
        klass: $rootScope.default_klass
        period: $rootScope.default_period
      for own k,v of state
        params[k] = v if v?
      params

classy.controller 'ExercisesCtrl', ($scope, $state, $stateParams, exercises) ->

  $scope.exercises = exercises
  $scope.params = $stateParams

  $scope.changePeriod = (diff) ->
    period = parseInt($stateParams.period, 10) + diff
    console.log period
    if period < 8 && period > 0
      $state.transitionTo 'exercises', {period: period}
