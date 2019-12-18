class ArchivesSpaceService < Sinatra::Base

  Endpoint.get_or_post('/reading_room_requests/search')
    .description("Search reading room requests")
    .params(*BASE_SEARCH_PARAMS)
    .paginated(true)
    .permissions([])
    .returns([200, ""]) \
  do
    params[:type] = ['reading_room_request']
    params[:sort] ||= "rrr_date_required_u_ssortdate desc"

    results = Search.search(params, nil)
    results = ReadingRoomRequest.prepare_search_results(results)
    results = AgencyReadingRoomRequest.prepare_search_results(results)

    json_response(results)
  end

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

  Endpoint.post('/reading_room_requests/bulk_set_status')
    .description("Bulk update request statuses")
    .params(["ids", String, "Comma separated list of ids to update"],
            ["status", String, "New status"])
    .permissions([])
    .returns([200, "(:success)"],
             [404, "Not found"]) \
  do
    params[:ids].split(',').each do |id|
      jsonmodel_type, id = id.split('::')
      if jsonmodel_type == 'agency_reading_room_request'
        request = AgencyReadingRoomRequest.get_or_die(id)
        request.set_status(params[:status])
      else
        request = ReadingRoomRequest.get_or_die(id)
        request.set_status(params[:status])
      end
    end

    json_response({:status => "success"})
  end
end
