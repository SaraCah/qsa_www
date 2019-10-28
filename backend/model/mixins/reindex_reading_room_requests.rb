module ReindexReadingRoomRequests

  def reindex_reading_room_requests!
    physical_representation_uris = []
    DB.open do |db|
      db[:physical_representation]
        .filter(:archival_object_id => self.id)
        .select(:id, :repo_id)
        .each do |row|
        physical_representation_uris << JSONModel(:physical_representation).uri_for(row[:id], :repo_id => row[:repo_id])
      end
    end

    PublicDB.open do |publicdb|
      publicdb[:reading_room_request]
        .filter(:item_uri => physical_representation_uris)
        .update(:system_mtime => Time.now)
    end
  end

  def update_from_json(json, opts = {}, apply_nested_records = true)
    result = super

    reindex_reading_room_requests!

    result
  end
end