$(function() {
  var updateBulkReadingroomRequestsCount = function() {
    var num_chkd = $('input[name=selected-item]:checked').length;

    if (num_chkd == 0) {
      $('.rrr-bulk-action-buttons').hide();
    } else {
      $('.rrr-selected-requests-count').text(num_chkd);
      $('.rrr-bulk-action-buttons').show();
    }

  }

  $('input[name=selected-item]').on('change', function(e) {
    updateBulkReadingroomRequestsCount();
  });

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

  updateBulkReadingroomRequestsCount();
});
