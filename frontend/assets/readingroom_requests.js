$(function() {
  var updateSelectedReadingroomRequests = function() {
    var chkd_items = $('input[name=selected-item]:checked');
    var num_all_items = $('input[name=selected-item]').length;
    var num_chkd = chkd_items.length;

    var id_a = Array();
    chkd_items.each(function () {
      id_a.push($(this).attr("value"));
    });
    var id_s = id_a.join();

    $('.rrr-bulk-action-buttons button').attr('data-id', id_s);

    if (num_chkd == 0) {
      $('.rrr-bulk-action-buttons').hide();
      $('.rrr-bulk-action-explainer').show();
    } else {
      $('.rrr-bulk-action-explainer').hide();
      $('.rrr-selected-requests-count').text(num_chkd);
      $('.rrr-bulk-action-buttons').show();
    }

    if (num_chkd == num_all_items) {
      $('.rrr-select-all-items').prop('checked', true);
    } else {
      $('.rrr-select-all-items').prop('checked', false);
    }
  }

  $('input[name=selected-item]').on('change', function(e) {
    updateSelectedReadingroomRequests();
  });

  $('.rrr-select-all-items').on('change', function(e) {
    $('input[name=selected-item]').prop('checked', $(e.target).prop('checked'));
    updateSelectedReadingroomRequests();
  });

  $('.rrr-bulk-action-buttons button').on('click', function(e) {
    var data = $(e.target).data();
    $.ajax({
      url: APP_PATH + 'reading_room_requests/bulk_set_status',
      method: 'POST',
      data: {
	'ids': data.id,
	'status': data.status
      },
      success: function() {
	$('input[name=selected-item]:checked').closest('tr').remove();
        updateSelectedReadingroomRequests();
      }
    })
  });

  $('.rrr-status-actions button').on('click', function(e) {
    var target = $(e.target);
    var data = $(e.target).data();
    $.ajax({
      url: APP_PATH + 'reading_room_requests/' + data.id + '/set_status',
      method: 'POST',
      data: {
        'status': data.status
      },
      success: function() {
        if (location.search.match('rrr_status_u_ssort')) {
	  target.closest('tr').remove();
	} else {
          location.reload();
	}
        updateSelectedReadingroomRequests();
      }
    })
  });

  $('.rrr-selected-item-cell').on('click', function(e) {
    $(e.target).find('input[type=checkbox]').trigger('click');
  });

  updateSelectedReadingroomRequests();
});
