$(document).ready ->

  # reset spinner
  $('#license-spinner').prop('selectedIndex', -1)

  # fetch the public repo information
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

      $('#select-all-repos').click ->
        $(this).closest('form').find(':checkbox').prop('checked', true);
        return false

      $('#select-non-forks').click ->
        $(this).closest('form').find(':checkbox').prop('checked', false);
        $(this).closest('form').find(':checkbox.non_fork').prop('checked', true);
        return false

      $('#unselect-all-repos').click ->
        $(this).closest('form').find(':checkbox').prop('checked', false);
        return false
    
      $('#repo-container').removeClass('is-loading')

  $('#license-spinner').change ->
    selected = $("select option:selected")
    $('#license-selection').html "Great! You selected <a href='http://choosealicense.com/licenses/#{selected.val()}'>#{selected.text()}</a>!"

  validator = new FormValidator("license-form", [
    name: "license"
    rules: "required"
  ], (errors, event) ->
    if $("input[type=checkbox]:checked").length == 0
      errors.push
        message: "You must select at least one repository!"

    if errors.length > 0
      event.preventDefault()
      errorStr = ""
      for error in errors
        errorStr += "<p>#{error.message}</p>"
      $('#form-error').html errorStr
      $('#form-error').css({ display: "block" })
      false
    else
      $('#form-error').css({ display: "none" })
  )