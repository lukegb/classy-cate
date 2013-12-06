class LayoutPopulator extends PagePopulator
  populate: ->
    @html.find('#cc-version').html(@vars.version)
    @html.find('#nav-dashboard').attr('href', @vars.current_url)
    @html.find('#nav-exercises').attr('href', @vars.timetable_url)
    @html.find('#nav-grades').attr('href', @vars.individual_records_link)
    @html.find('#cc-current-year').html("(#{@vars.current_year})")

    if window.classy_cate_script_version != CLASSY_CATE_SCRIPT_VERSION
      @html.find('#page-content').before('<div class="alert alert-error">' +
                                    'Your Classy-CATE script is out of date! ' +
                                    '<a href="http://classy-cate.herokuapp.com/classy-cate.user.js">' +
                                      'Click Here'+
                                    '</a>' +
                                    ' to update to CCv' + CLASSY_CATE_SCRIPT_VERSION + '</a>')

    # New Bindings
    @html.find('#nav-dashboard').bind 'click', load_dashboard_page
    @html.find('#nav-exercises').bind 'click', load_exercises_page
    @html.find('#nav-grades').bind 'click', load_grades_page
    @html.find('#old-cate-button').bind 'click', activate_nostalgia_mode
