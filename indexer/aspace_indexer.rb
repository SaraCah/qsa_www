class IndexerCommon
  @@record_types << :reading_room_request
  add_attribute_to_resolve('requested_item')

  add_indexer_initialize_hook do |indexer|
    QSAId.mode(:indexer)
    require_relative '../common/qsa_id_registrations'

    indexer.add_document_prepare_hook {|doc, record|
      if doc['primary_type'] == 'reading_room_request'
        if record['record']['date_required']
          doc['rrr_date_required_u_ssortdate'] = "%sT00:00:00Z" % [Time.at(record['record']['date_required'] / 1000).to_date.iso8601]
        end

        doc['rrr_date_created_u_ssortdate'] = record['record']['create_time']
        doc['rrr_status_u_ssort'] = record['record']['status']

        item = record['record']['requested_item']['_resolved']
        user = record['record']['requesting_user']

        doc['rrr_requested_item_qsa_id_u_ssort'] = item['qsa_id_prefixed']
        doc['rrr_requested_item_qsa_id_u_sort'] = IndexerCommon.sort_value_for_qsa_id(item['qsa_id_prefixed'])
        doc['rrr_requested_item_availability_u_ssort'] = item['calculated_availability']
        doc['rrr_requesting_user_u_ssort'] = user['last_name'] + ', ' + user['first_name']
      end
    }
  end

end
