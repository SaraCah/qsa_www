$(function() {
  $('.rrr-status-actions button').on('click', function(e) {
    var data = $(e.target).data();
    $.ajax({
      url: APP_PATH + 'reading_room_requests/' + data.id + '/set_status',
      method: 'POST',
      data: {
        'status': data.status
      },
      success: function() {
        location.reload();
      }
    })
  });
});
