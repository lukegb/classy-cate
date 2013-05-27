PERIOD = null
TIMELINE_STRUCTURE = {
      title : ['id','type']
      extendedTitle : ['name']
      content :
        names : ['HAND IN', 'SPEC', 'GIVENS']
        keys : ['handin', 'spec', 'given_element']
  }

#///////////////////////////////////////////////////////////////////////////////
# Routeing
#///////////////////////////////////////////////////////////////////////////////
# Below is the implementation for loading views into the web page. 
# The process runs like so - ajax request is made via the 
# classy.load_cate_page function...
# ...which then creates an iframe that contains the html response from CATe, and
# extracts the body. 
# The body is then sent to the callback given, typically an function that runs
# extraction on the body, then calls the populate method.

window.initial_load = ->
  path = window.location.pathname
  if path is '/'
    if !hash? or hash == 'dashboard'
      hash = (window.location.hash).replace('#', 'dashboard')
      load_dashboard_page null, populate_layout
    else if hash == "grades"
      load_grades_page()
    else if hash == "timetable"
      load_exercises_page()
  else
    cate_notice = $('<div>Classy CATE hasn\'t been implemented for this page yet<br/><a href="https://github.com/PeterHamilton/classy-cate">Implement it!</a></div>')
    cate_notice.attr('style', 'padding: 20px; margin-bottom: 20px; text-shadow: 0 1px 0 rgba(255, 255, 255, 0.5); border: 3px solid #eed3d7; -webkit-border-radius: 4px; -moz-border-radius: 4px; border-radius: 4px; color: #b94a48; background-color: #f2dede; font-size: 18px; text-align: center;')
    $('body').prepend(cate_notice)

load_cate_page = (url, callback) ->
  console.log 'loading url - ' + url
  $.ajax
    type: 'POST'
    url: '/cate_requests/portal.json'
    data: {path : url}
    success: (data) ->
      window.last_url = data.path
      data = data.content.split(/<body.*>/)[1].split('</body>')[0]
      # totally remove all icons before dom parse
      data = data.replace(/<img[^>]*>/g, '')
      body = $('<div/>').append(data)
      callback body

load_dashboard_page = (e, cb) ->
  e.preventDefault() if e?
  window.location.hash = "dashboard"
  url = '/'
  load_cate_page url, (body) ->
    main_page_vars = extract_main_page_data(body)
    $('#page-content').html('').append window.DASHBOARD.clone()
    if cb? then cb(main_page_vars)
    populate_main_page(main_page_vars)


load_grades_page = (e) ->
  e.preventDefault() if e?
  window.location.hash = "grades"
  load_cate_page $('#nav-grades').attr('href'), (body) ->
    grade_page_vars = extract_grades_page_data(body)
    $('#page-content').html('').append window.GRADES.clone()
    populate_grades_page(grade_page_vars)

load_exercises_page = (e, fallback, shifting, url) ->

  if e?
    e.preventDefault()
    url = e.target.getAttribute('href')

  get_period_from_href = (href) ->
    parseInt href.split('period=')[1][0]

  alter_href_by = (href, i) ->
    p = (get_period_from_href href)
    href.replace(('period=' + p),('period=' + (p + i)))

  isHoliday = (period) -> period%2 == 0

  get_url_for_period = (p) ->
    crrt = $('#nav-exercises').attr('href').split('period=')
    crrt[0] + 'period=' + p + crrt[1][1..]

  window.location.hash = "timetable"

  href = $('#nav-exercises').attr('href')
  if shifting?
    PERIOD = PERIOD + shifting
    href = get_url_for_period PERIOD
  else if fallback?
    href = alter_href_by href, (-1)
  else if url?
    href = url

  PERIOD = get_period_from_href href

  load_cate_page href, (body) ->
    exercise_page_vars = extract_exercise_page_data body
    go_forth_and_multiply = true
    if isHoliday(get_period_from_href href) and (not shifting? or url?)
      noOfExercises = 0
      for m in exercise_page_vars.modules
        noOfExercises += m.exs.length if m.exs?
      if noOfExercises == 0
        go_forth_and_multiply = false
        load_exercises_page e, true, null
    if go_forth_and_multiply
      $('#page-content').html('').append window.EXERCISES.clone()
      populate_exercises_page(exercise_page_vars)

download_cate_material = (path) ->
  window.location.href = '/cate_requests/download?path=' + path


#///////////////////////////////////////////////////////////////////////////////
# Extraction
#///////////////////////////////////////////////////////////////////////////////
# Excercise Page
# html - A jQuery object representing the page body
extract_exercise_page_data = (html) ->

  # Extracts full title e.g. Spring Term 2012-2013
  extract_term_title = (html) ->
    html.find('tr').eq(0).find('h1').eq(0).text()

  # Converts a CATE style date into a JS Date object
  # e.g. '2013-1-7' -> Mon Jan 07 2013 00:00:00 GMT+0000 (GMT)
  parse_date = (input) ->
    [year, month, day] = input.match(/(\d+)/g)
    new Date(year, month - 1, day) # JS months index from 0

  # Extracts the academic years applicable
  # e.g. "Easter Period 2012-2013" -> ["2012", "2013"]
  extract_academic_years = (body) ->
    body.find('h1').text()[-9..].split('-')

  extract_start_end_dates = (fullTable, years) ->
    # Converts a month into an int (indexed from 1)
    # e.g. "January" -> 1
    # month - Month name as a capitalised string
    month_to_int = (m) ->
      months = ['January', 'February', 'March', 'April', 'May', 'June', 'July',
                'August', 'September', 'October', 'November', 'December']
      return 6 if m == 'J'
      rexp = new RegExp(m,'g')
      for month,i in months
            if rexp.test(month) then return i+1

    # Extracts months from table row
    # e.g. ["January", "February", "March"]
    # table_row - The Timetable table row jQuery Object
    extract_months = (table_row) ->
      table_headers = ($(cell) for cell in table_row.find('th'))
      month_cells = (c for c in table_headers when c.attr('bgcolor') == "white")
      month_names = (c.text().replace(/\s+/g, '') for c in month_cells)
      month_ids = month_names.map month_to_int
      return month_ids

    # Extracts days from table row
    # e.g. ["1", "2", "3"]
    # table_row - The Timetable table row jQuery Object
    extract_days = (table_row) ->
      table_headers = ($(cell) for cell in table_row.find('th'))
      days_text = (c.text() for c in table_headers)
      valid_days = (d for d in days_text when d.replace(/\s+/g, '') != '') 
      days_as_ints = valid_days.map parseFloat # Parse int was going nuts, '23' -> 54???
      return days_as_ints

    # TODO: What if the timetable crosses year boundaries?
    #       e.g over new year/christmas?

    [first_month, others..., last_month] = extract_months $(fullTable).find('tr').eq(0)

    year = if first_month < 9 then years[1] else years[0]

    day_headers = $(fullTable).find('tr').eq(2).find('th')

    col_buf = 0
    col_buf += 1 while $(day_headers[col_buf]).is(":empty")

    [first_day, others..., last_day] = extract_days $(fullTable).find('tr').eq(2)

    return {  # remember _day in yyyy-mm-dd format
      start: year + '-' + first_month + '-' + first_day
      end: year + '-' + last_month + '-' + last_day
      colBufferToFirst: col_buf - 1
    }

  # Extracts module details from a cell jQuery object
  process_module_cell = (cell) ->
    [id, name] = cell.text().split(' - ')
    return {
      id : id
      name : name.replace(/^\s+|\s+$/g, '')
      notesLink : cell.find('a').eq(0).attr('href')
    }

  # Add the parsed exercises to the given module
  # module - the module to attach the exercises to
  # exercise_cells - An array of cells (jQuery objects)
  process_exercises_from_cells = (module, exercise_cells) ->
    if not exercise_cells? then return null
    module.exercises ?= []

    current_date = parse_date dates.start
    current_date.setDate(current_date.getDate() - dates.colBufferToFirst)
    for ex_cell in exercise_cells
      colSpan = parseInt($(ex_cell).attr('colspan') ? 1)
      colSpan = 1 if colSpan == NaN
      if $(ex_cell).attr('bgcolor')? and $(ex_cell).find('a').length != 0
        [id, type] = $(ex_cell).find('b').eq(0).text().split(':')
        hrefs = ($(anchor).attr('href') for anchor in $(ex_cell).find('a') when $(anchor).attr('href')?)
        [mailto, spec, givens, handin] = [null, null, null, null]
        for href in hrefs
          if /mailto/i.test(href)
            mailto = href
          else if /SPECS/i.test(href)
            spec = href
          else if /given/i.test(href)
            givens = href
          else if /handins/i.test(href)
            handin = href

        end = new Date(current_date.getTime())
        end.setDate(end.getDate() + colSpan - 1)
        exercise_data = {
          id : id, type : type, start : new Date(current_date.getTime())
          end : end, moduleName : module.name
          name : $(ex_cell).text()[(id.length + type.length + 2)..].replace(/^\s+|\s+$/g,'')
          mailto : mailto, spec : spec, givens : givens, handin : handin
        }

        module.exercises.push(exercise_data)
      current_date.setDate (current_date.getDate() + colSpan)

  extract_module_exercise_data = (fullTable) ->

    # Returns whether or not an element is a module container
    # elem - jQuery element
    is_module = (elem) ->
      elem.find('font').attr('color') == "blue"

    allRows = $(fullTable).find('tr')
    modules = []
    count = 0
    while count < allRows.length
      current_row = allRows[count]
      following_row_count = 0
      module_elem = $($(current_row).find('td').eq(1))
      if is_module(module_elem)
        module_data = process_module_cell module_elem

        following_row_count = $(current_row).find('td').eq(0).attr('rowspan') - 1
        following_rows = allRows[count+1..count+following_row_count]

        exerciseCells = ($(row).find('td')[1..] for row in following_rows)
        exerciseCells.push($(current_row).find('td')[4..])
        exerciseCells = (cs for cs in exerciseCells when cs?)

        process_exercises_from_cells(module_data, cells) for cells in exerciseCells

        modules.push module_data
      count += following_row_count + 1
    return modules

  term_title = extract_term_title html
  timetable = (tb for tb in html.find('table') when $(tb).attr('border') == "0")
  dates = extract_start_end_dates timetable, extract_academic_years html   # WRONG
  modules = extract_module_exercise_data timetable
  m.exercises.sort ((a,b) -> if a.start < b.start then -1 else 1) for m in modules
  return {
    modules : modules
    start : dates.start, end : dates.end
    term_title : term_title
  }

#///////////////////////////////////////////////////////////////////////////////
# Extraction
#///////////////////////////////////////////////////////////////////////////////
# CATE Homepage
# html - A jQuery object representing the page body
extract_main_page_data = (html) ->
  current_url = window.last_url
  current_year = current_url.match("keyp=([0-9]+)")[1] #TODO: Error check
  current_user = current_url.match("[0-9]+:(.*)")[1] # TODO: Error Check

  version = html.find('table:first td:first').text()

  profile_image_src = html.find('table:eq(2) table:eq(1) tr:eq(0) img').attr('src')

  profile_fields = html.find('table:eq(2) table:eq(1) tr:eq(1) td').map (i, e) -> $(e).text()
  first_name = profile_fields[0]
  last_name = profile_fields[1]
  login = profile_fields[2]
  category = profile_fields[3]
  candidate_number = profile_fields[4]
  cid = profile_fields[5]
  personal_tutor = profile_fields[6]

  available_years = html.find('select[name=newyear] option').map (index, elem) ->
    elem = $(elem)
    {text: elem.html(), href: elem.attr('value')}
  available_years = available_years.slice(1)

  other_func_links = html.find('table:eq(2) table:eq(9) tr td:nth-child(3) a').map (index, elem) ->
    $(elem).attr('href')

  grading_schema_link = other_func_links[0]
  documentation_link = other_func_links[1]
  extensions_link = other_func_links[2]
  projects_portal_link = other_func_links[3]
  individual_records_link = other_func_links[4]

  default_class = html.find('input[name=class]:checked').val()
  default_period = html.find('input[name=period]:checked').val()

  keyt = html.find('input[type=hidden]').val()

  timetable_url = '/timetable.cgi?period=' + default_period + '&class=' + default_class + '&keyt=' + keyt

  return {
    current_url: current_url
    current_year: current_year
    current_user: current_user
    version: version
    profile_image_src: profile_image_src
    first_name: first_name
    last_name: last_name
    login: login
    category: category
    candidate_number: candidate_number
    cid: cid
    personal_tutor: personal_tutor
    available_years: available_years
    grading_schema_link: grading_schema_link
    documentation_link: documentation_link
    extensions_link: extensions_link
    projects_portal_link: projects_portal_link
    individual_records_link: individual_records_link
    default_class: default_class
    default_period: default_period
    keyt: keyt
    timetable_url: timetable_url
  }

#///////////////////////////////////////////////////////////////////////////////
# Extraction
#///////////////////////////////////////////////////////////////////////////////
# Givens Page for Exercise
# html - A jQuery object representing the page body
extract_givens_page_data = (html) ->

  categories = []

  # Select the tables
  html.find('table [cellpadding="3"]')[2..].each(->
    category = {}
    if $(this).find('tr').length > 1  # Only process tables with content
      category.type = $(this).closest('form').find('h3 font').html()[..-2]
      rows = $(this).find('tr')[1..]
      category.givens = []
      for row in rows
        if (cell = $(row).find('td:eq(0) a')).attr('href')?
          category.givens.push {
            title : cell.html()
            link  : cell.attr('href')
          }
      categories.push category
    )    

  # Return an array of categories, each element containing a type and rows
  # categories = [ { type = 'TYPE', givens = [{title, link}] } ]
  return categories

#///////////////////////////////////////////////////////////////////////////////
# Extraction
#///////////////////////////////////////////////////////////////////////////////
# Grades/Student Record Page
# html - A jQuery object representing the page body
extract_grades_page_data = (html) ->
  process_header_row = (row) ->
    # TODO: Regex out the fluff
    return {
      name: text_extract row.find('td:eq(0)')
      term: text_extract row.find('td:eq(1)')
      submission: text_extract row.find('td:eq(2)')
      level: text_extract row.find('td:eq(3)')
      exercises: []
    }

  process_grade_row = (row) ->
    return {
      id: parseInt(text_extract row.find('td:eq(0)'))
      type: text_extract row.find('td:eq(1)')
      title: text_extract row.find('td:eq(2)')
      set_by: text_extract row.find('td:eq(3)')
      declaration: text_extract row.find('td:eq(4)')
      extension: text_extract row.find('td:eq(5)')
      submission: text_extract row.find('td:eq(6)')
      grade: text_extract row.find('td:eq(7)')
    }

  extract_modules = (table) ->
    grade_rows = table.find('tr')
    grade_rows = grade_rows.slice(2)

    modules = []
    current_module = null;
    grade_rows.each (i, e) ->
      row_elem = $(e)
      tds = row_elem.find('td')
      if tds.length > 1 # Ignore spacer/empty rows
        if $(tds[0]).attr('colspan')
          current_module = process_header_row(row_elem)
          modules.push current_module
        else
          current_module.exercises.push process_grade_row(row_elem)

    return modules

  # TODO: Regex extract useful values
  subscription_last_updated = text_extract html.find('table:eq(7) table td:eq(1)')
  submissions_completed = text_extract html.find('table:eq(7) table td:eq(4)')
  submissions_extended = text_extract html.find('table:eq(7) table td:eq(6)')
  submissions_late = text_extract html.find('table:eq(7) table td:eq(8)')

  required_modules = extract_modules html.find('table:eq(9)')
  optional_modules = extract_modules html.find('table:eq(-2)')

  return {
    stats:
      subscription_last_updated: subscription_last_updated
      submissions_completed: submissions_completed
      submissions_extended: submissions_extended
      submissions_late: submissions_late
    required_modules: required_modules
    optional_modules: optional_modules
  }


#///////////////////////////////////////////////////////////////////////////////
# Extraction
#///////////////////////////////////////////////////////////////////////////////
# Notes Page for Module
# html - A jQuery object representing the page body
extract_notes_page_data = (html) ->

  process_notes_rows = (html) ->
    html.find('table [cellpadding="3"]').find('tr')[1..]

  notes = []
  for row in ($(r) for r in process_notes_rows html)
    title = row.find('td:eq(1)').text()
    link = $(row.find('td:eq(1) a'))
    if link.attr('href')? && link.attr('href') != ''
      notes.push {
        type: "resource"
        title: title
        link: link.attr('href')
      }
    else if link.attr('onclick')? # Remote page
      identifier = link.attr('onclick').match(/clickpage\((.*)\)/)[1]
      href = "showfile.cgi?key=2012:3:#{identifier}:c3:NOTES:peh10"
      notes.push {
        type: "url"
        title : title
        link : href
      }

  return { notes: notes }

#///////////////////////////////////////////////////////////////////////////////
# Construction
#///////////////////////////////////////////////////////////////////////////////
populate_notes = (notes_data, header) ->
  notes_header = $('#notes-modal-header')
  notes_header.find('h3').remove()
  notes_header.append("<h3>#{header}</h3>")
  notes_body = $("#notes-modal-tbody")
  notes_body.html('')
  for note, i in notes_data.notes
    row = $('<tr/>')
    row.append("<td>#{i+1}</td>")
    if note.type == "url"
      row.append("<td><a href='#{note.link}' target='_blank'>#{note.title}</a></td>")
    else
      row.append("<td><a href='#{note.link}'>#{note.title}</a></td>")
    notes_body.append(row)

#///////////////////////////////////////////////////////////////////////////////
# Construction
#///////////////////////////////////////////////////////////////////////////////
populate_grades_page = (vars) ->

  grade_to_class = (grade) ->
    switch grade
      when "A*", "A+", "A" then "progress-success"
      when "B"  then "progress-info"
      when "C" then "progress-warning"
      when "D", "E", "F" then "progress-danger"

  grade_to_width = (grade) ->
    width = switch grade
      when "A*" then 100
      when "A+" then 89
      when "A"  then 79
      when "B"  then 69
      when "C"  then 59
      when "D"  then 49
      when "E"  then 39
      when "F"  then 29
      else 0
    "#{width}%"

  render_module = (module) ->
    module_elem = $('#module_template .row').clone()
    module_elem.find('.module-title').html(module.name)

    grades_table = module_elem.find('.module-grades')
    if module.exercises.length == 0
      grades_table.append($('<tr><td colspan="8">No exercises for this module.</td></tr>'))
    else
      $(module.exercises).each (i, exercise) ->
        exercise_elem = $('#exercise_template tr').clone()
        exercise_elem.find('.exercise-id').html(exercise.id)
        exercise_elem.find('.exercise-type').html(exercise.type)
        exercise_elem.find('.exercise-title').html(exercise.title)
        exercise_elem.find('.exercise-set-by').html(exercise.set_by)
        exercise_elem.find('.exercise-declaration').html(exercise.declaration)
        exercise_elem.find('.exercise-extension').html(exercise.extension)
        exercise_elem.find('.exercise-submission').html(exercise.submission)

        switch exercise.grade
          when ""
            exercise_elem.find('.exercise-grade-container').html("No Record")
          when "n/a"
            exercise_elem.find('.exercise-grade-container').html('<i class="icon-legal" /> Awaiting Marking')
          when "N/P"
            exercise_elem.find('.exercise-grade-container').html('<i class="icon-lock" /> Marked, Not Published')
          else
            exercise_elem.find('.progress').addClass(grade_to_class(exercise.grade))
            exercise_elem.find('.progress .bar').css('width', grade_to_width(exercise.grade))
            exercise_elem.find('.exercise-grade').html(exercise.grade)
        grades_table.append(exercise_elem)
    return module_elem

  $('#cc-subscription-updated').html(vars.stats.subscription_last_updated)
  $('#cc-submissions-completed').html(vars.stats.submissions_completed)
  $('#cc-submissions-extended').html(vars.stats.submissions_extended)
  $('#cc-submissions-late').html(vars.stats.submissions_late)

  $(vars.required_modules).each (i, module) ->
    $('#cc-required-modules').append(render_module module)

  $(vars.optional_modules).each (i, module) ->
    $('#cc-optional-modules').append(render_module module)

#///////////////////////////////////////////////////////////////////////////////
# Construction
#///////////////////////////////////////////////////////////////////////////////
populate_main_page = (vars) ->
  $('#cc-identity-profile-image').attr('src', '/cate_requests/profile_pic')
  $('#cc-identity-first-name').html(vars.first_name)
  $('#cc-identity-last-name').html(vars.last_name)
  $('#cc-identity-login').html(vars.login)
  $('#cc-identity-category').html(vars.category)
  $('#cc-identity-candidate-number').html(vars.candidate_number)
  $('#cc-identity-cid').html(vars.cid)
  $('#cc-identity-personal-tutor').html(vars.personal_tutor)

  vars.available_years.each (i, val) ->
    $('#cc-year-dropdown').append '<li><a href="' + val.href + '">' + val.text + '</a></li>'

  $('#cc-other-projects-portal').attr('href', vars.projects_portal_link)
  $('#cc-other-extensions').attr('href', vars.extensions_link)
  $('#cc-other-documentation').attr('href', vars.documentation_link)

  $('#class-selector li').bind 'click', ->
    $('#current-class')
      .text($(this).text())
      .attr('value',$(this).find('a').attr('value'))
  $('#ex-go-btn').data('keyt',vars.keyt)

  $('#ex-go-btn').bind 'click', ->
    p = $('#term-selector .active').attr 'value'
    c = $('#current-class').attr 'value'
    kt = $(this).data('keyt')
    url = "/timetable.cgi?period=#{p}&class=#{c}&keyt=#{kt}"
    load_exercises_page(null, null, null, url)

  if (period = parseInt vars.default_period)%2 == 0 then period = period - 1
  $('#current-class').attr 'value', vars.default_class
  $('#class-selector a').each ->
    if $(this).attr('value') == vars.default_class
      $('#current-class').text($(this).text()) 
  $('#term-selector .btn').each ->
    $(this).addClass('active') if $(this).attr('value') == period.toString()

  lower = new Date()
  upper = new Date(lower.getTime() + 1000*60*60*24*7 + 1)  # to include full day
  load_cate_page $('#nav-exercises').attr('href'), (body) ->
    vars = extract_exercise_page_data body
    [exs_due, exs_late] = [[],[]]
    for m in vars.modules
      for e in m.exercises
        if lower <= e.end <= upper then exs_due.push e
        else if e.end < lower and e.handin? then exs_late.push e
    if exs_due.length != 0
      [vars, fake_module] = [{},{}]
      fake_module.exercises = exs_due
      vars.modules = [fake_module]
      exs = (populate_exercises_page vars, true).sort (a,b) ->
        a.end - b.end
      $('#exercises_table').append(e.row) for e in exs
      create_timeline
        structure : TIMELINE_STRUCTURE, moments : exs
        destination : $('#exercise_timeline')
      $('#exercises_table th').css('cursor','pointer').click -> 
        $('#exercise_timeline .circle.origin').trigger 'click'
      for e in exs
        day = 1000*60*60*24
        [tomorrow, c] = [new Date(lower.getTime() + day), '']
        if (e.end < tomorrow) 
          c = 'label-important'
        else if (e.end < (new Date(tomorrow.getTime() + 2*day)))
          c = 'label-warning'
        due_cell = e.row.find('.due')
        label = $("<span class='label'>#{due_cell.text()}</span>")
        label.addClass(c + ' due_label')
        due_cell.html('').append label
        e.row.data 'bubble', e.info_box
        e.row.hover \
          (-> $(this).data('bubble').trigger('mouseenter')), \
          (-> $(this).data('bubble').trigger('mouseleave'))
        e.row.click -> $(this).data('bubble').trigger('click')
        e.row.css 'cursor', 'pointer'
    else populate_exercises_page null, true

#///////////////////////////////////////////////////////////////////////////////
# Construction
#///////////////////////////////////////////////////////////////////////////////
populate_exercises_page = (vars, forDashboard) ->

  format_date = (d) ->
    pad = (a,b) ->
      (1e15+a+"").slice(-b)
    pad(d.getDate(),2) + '/' + pad(d.getMonth()+1,2) + '/' + d.getFullYear()

  populate_exercise_row = (row, ex) ->
    id_cell = row.find('.id')
    if forDashboard?
      id_cell.text(ex.moduleName)
      id_cell = row.find('.name') 
    if ex.handin?
        id_cell.html('')
        handin_anchor = $(document.createElement('a'))
          .attr('href',ex.handin).html('Hand in').appendTo(id_cell)
        handin_anchor.addClass(
          if ex.end > (new Date()) then 'handin_link btn btn-primary' else 'btn btn-danger late_handin')
    else
      if not forDashboard? or !/\S/.test(ex.name)
        id_cell.html('{'+ex.id+':'+ex.type+'}') 
      else id_cell.html('')
    if /\S/.test(ex.name)
      name_cell = row.find('td.name')
      if not forDashboard?
        name_cell.text(ex.name)
      else name_cell.html(name_cell.html() + ex.name)
      
    row.find('td.set').text(format_date ex.start)
    due_text = format_date ex.end
    if forDashboard?
      [day, month, date] = ex.end.toString().split(' ')
      due_text = day + ' ' + date

    row.find('td.due').text due_text
    row.find('td.due').text

    if ex.spec?
      (specCell = row.find('.spec')).text('')
      ex.spec_element = $(document.createElement('a'))
        .attr('href',ex.spec)
        .html('Spec Link')
        .appendTo(specCell)
        .click (e) ->
          console.log 'Clicked'
          if e? 
            e.preventDefault()
            e.stopPropagation()
          download_cate_material $(this).attr 'href'

    if ex.givens?
      givensCell = row.find('.given').text('')
      ex.given_element = $(document.createElement('a')).attr('href',ex.givens)
        .html('Givens').appendTo(givensCell)
        .data('ex_title', row.find('.name').text())
        .bind 'click', (e) ->
          e.preventDefault()
          url = $(this).attr 'href'
          $('#active_given').removeAttr 'id'
          $(this).attr 'id', 'active_given'
          load_cate_page url, (body) ->
            givens_data = extract_givens_page_data(body)
            populate_givens(givens_data, $('#active_given').data('ex_title'))
            $('#givens-modal').modal('show')


  destination_div = $('#page-content')
  destination_div = $('#exercise-timeline') if forDashboard?
  (modules = vars.modules) if vars?
  if not forDashboard?
    $('#term_title').text('Timetable - ' + vars.term_title)


  if vars? then for module in (m for m in modules when m.exercises[0]?) # Ignore empty module  
    if not forDashboard?
      module_header = $('<h3>' + module.id + ' - ' + module.name + '</h3>') 

    if module.notesLink? and not forDashboard?
      note_link = $('<a/>').attr('href', module.notesLink).html('Notes')
        .data('module_title',module_header.text())  # Save title link for modal

      note_link.bind 'click', (e) ->
          e.preventDefault()
          url = $(this).attr 'href'
          $('#active_note').removeAttr 'id'
          $(this).attr 'id', 'active_note'
          load_cate_page url, (body) ->
            notes_data = extract_notes_page_data(body)
            populate_notes(notes_data, $('#active_note').data('module_title'))
            $("#notes-modal").modal('show')
      module_header.append(" - ").append(note_link)

    module_table = $('#exercises_table')
    if not forDashboard? 
      module_table = $('#exercises_template').clone()
    module_table.removeClass('hidden')

    for exercise in module.exercises
      row = $('#exercise_row_template').clone()
      if not forDashboard?
        row.removeClass('hidden').appendTo(module_table)
      else exercise.row = row.removeClass('hidden')  # rememeber to append
      populate_exercise_row row, exercise
    destination_div.append(module_header).append(module_table) if not forDashboard?

    if forDashboard? then return module.exercises

    placeholder = $('<div/ class="timeline_slider">').appendTo destination_div
    timeline = create_timeline
              destination : placeholder
              structure : TIMELINE_STRUCTURE, moments : module.exercises
    .hide()

    timeline_icon = $('<i/ rel="tooltip" title="Toggle timeline" class="icon-time timeline_toggle">')
      .data 
        'clicked' : false
        'timeline' : timeline
        'placeholder' : placeholder
      .bind 'click', ->
        $(this).data 'clicked', (clicked = !$(this).data 'clicked')
        [timeline, placeholder] = [$(this).data('timeline'), $(this).data('placeholder')]
        if clicked
          placeholder.animate {minHeight : 150}, {duration : 400, complete : -> timeline.fadeIn()}
        else
          timeline.fadeOut
            complete : -> placeholder.animate {minHeight : 0, height : 'auto'}, {duration : 400}
      .tooltip {placement : 'left', delay : {show : 500, hide : 100}}

    module_header.append timeline_icon

  if not modules? or Math.max((m.exercises.length for m in vars.modules)...) <= 0
    no_modules = $('<div/>').css
      textAlign : 'center', paddingTop : '50px', paddingBottom : '50px'
    .append $('<div/ class="well">').append("<h4>There's no handins here!</h4>")
    $('#page-content').append no_modules

  if not forDashboard?
    $('#back_term_btn').bind 'click', ->
        if PERIOD != 1 then load_exercises_page null, null, -1
    $('#next_term_btn').bind 'click', ->
        if PERIOD != 6 then load_exercises_page null, null, 1



#///////////////////////////////////////////////////////////////////////////////
# Construction
#///////////////////////////////////////////////////////////////////////////////
populate_givens = (givens_data, header) ->
  # givens_data = [ { type = 'TYPE', givens = [{title, link}] } ]
  givens_header = $('#givens-modal-header')
  givens_header.find('h3').remove()
  givens_header.append("<h3>#{header}</h3>")
  givens_table = $('#givens-table')
  givens_table.html('')
  for category in givens_data
    head = $('<thead/>').append $("<tr><th colspan='2'><h4>#{category.type}</h4></th></tr>")
    head.append $('<tr><th class="id">ID</th><th>Link</th></tr>')
    tbody = $('<tbody/>')
    for given, i in category.givens
      row = $('<tr/>')
      row.append("<td>#{i+1}</td>")
      row.append("<td><a href='#{given.link}'>#{given.title}</a></td>")
      tbody.append row
    givens_table.append(head)
    givens_table.append(tbody)


#///////////////////////////////////////////////////////////////////////////////
# Helper Functions
#///////////////////////////////////////////////////////////////////////////////

activate_nostalgia_mode = ->
  nostalgia_colors = ['Teal', 'DarkCyan', 'DeepSkyBlue', 'DarkTurquoise', 'MediumSpringGreen',
                     'Lime', 'SpringGreen', 'Aqua', 'Cyan', 'MidnightBlue', 'DodgerBlue',
                     'LightSeaGreen', 'Turquoise', 'RoyalBlue', 'SteelBlue', 'MediumTurquoise',
                     'CadetBlue', 'CornflowerBlue', 'MediumAquaMarine']

  $('body, footer, div, span, td, input').each (index, elem) ->
    random_nostalgia_color = nostalgia_colors[Math.floor(Math.random()*nostalgia_colors.length)]
    $(elem).css('background', random_nostalgia_color)

  $('#old-cate-button').unbind()
  $('#old-cate-button').html("Mother of God, make it stop!")
  $('#old-cate-button').bind 'click', ->
    alert('Nope, you made your bed, now lie in it...')

text_extract = (html) ->
  html.text().trim().replace(/(\r\n|\n|\r)/gm,"");

populate_layout = (vars) ->
  console.log 'Populating layout'
  $('#cc-version').html(vars.version)
  $('#nav-dashboard').attr('href', vars.current_url)
  $('#nav-exercises').attr('href', vars.timetable_url)
  $('#nav-grades').attr('href', vars.individual_records_link)
  $('#cc-current-year').html("(#{vars.current_year})")

  # New Bindings
  $('#nav-dashboard').bind 'click', load_dashboard_page
  $('#nav-exercises').bind 'click', load_exercises_page
  $('#nav-grades').bind 'click', load_grades_page
  $('#old-cate-button').bind 'click', activate_nostalgia_mode