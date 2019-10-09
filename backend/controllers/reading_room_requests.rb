class ArchivesSpaceService < Sinatra::Base

  # FIXME Need permissions on these too
  Endpoint.get('/reading_room_requests')
    .description("List reading room requests")
    .permissions([])
    .paginated(true)
    .returns([200, "[(:reading_room_request)]"]) \
  do
    handle_listing(ReadingRoomRequest, params)
  end

end
