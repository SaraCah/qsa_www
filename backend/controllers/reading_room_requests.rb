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

  Endpoint.get('/reading_room_requests/:id')
    .description("Get a reading room request by ID")
    .params(["id", :id],
            ["resolve", :resolve])
    .permissions([])
    .returns([200, "(:reading_room_request)"],
             [404, "Not found"]) \
  do
    json = ReadingRoomRequest.to_jsonmodel(params[:id])
    json_response(resolve_references(json, params[:resolve]))
  end


end
