class IndexerCommon
  @@record_types << :reading_room_request
  @@resolved_attributes << 'requested_item'

  add_indexer_initialize_hook do |indexer|
    indexer.add_document_prepare_hook {|doc, record|
      if doc['primary_type'] == 'reading_room_request'
        if record['record']['date_required']
          doc['rrr_date_required_u_ssortdate'] = "%sT00:00:00Z" % [Time.at(record['record']['date_required'] / 1000).to_date.iso8601]
        end

        doc['rrr_date_created_u_ssortdate'] = record['record']['create_time']
        doc['rrr_status_u_ssort'] = record['record']['status']

        # doc
        require 'pp';$stderr.puts("\n*** DEBUG #{(Time.now.to_f * 1000).to_i} [aspace_indexer.rb:16 CoarseWhippet]: " + {%Q^doc^ => doc}.pretty_inspect + "\n")
      end
    }
  end

end
