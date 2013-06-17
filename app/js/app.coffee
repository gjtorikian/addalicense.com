$(document).ready ->

  if window.location.pathname == "/add"
    $('#license-spinner').prop('selectedIndex', -1)

    $.ajax "/repos",
      type: "GET"
      dataType: 'html'
      beforeSend: (jqXHR) ->
        $('#repo-container').addClass('is-loading')
        jqXHR.setRequestHeader("Accept", "application/json")
      error: (jqXHR, textStatus, errorThrown) ->
        data = jqXHR.responseText
        $('#repo-container').html(data.errors)
        $('#repo-container').removeClass('is-loading')
      success: (data, textStatus, jqXHR) ->
        message = "<p>Here's a list of your public repositories that don't have a LICENSE file:</p>" + data
        $('#repo-container').html data
        $('#repo-container').removeClass('is-loading')

    $('#license-spinner').change ->
      selected = $("select option:selected")
      $('#license-selection').html "Great! You selected <a href='http://localhost:4000/licenses/#{selected.val()}'>#{selected.text()}</a>!"
      