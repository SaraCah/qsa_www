class ReadingRoomRequestsController < ApplicationController

  include ApplicationHelper

  # TODO: review access controls for these endpoints
  set_access_control  "view_repository" => [
                                            :index,
                                           ]

  def index
    @search_data = Search.for_type(session[:repo_id], "reading_room_request", params)
  end

end
