class ReadingRoomRequestsController < ApplicationController

  RESOLVES = ['requested_item']

  include ApplicationHelper

  # TODO: review access controls for these endpoints
  set_access_control  "view_repository" => [:index, :show]

  def index
    @search_data = Search.for_type(session[:repo_id], "reading_room_request", params)
  end

  def show
    @reading_room_request = JSONModel(:reading_room_request).find(params[:id], find_opts.merge('resolve[]' => RESOLVES))
  end

  def current_record
    @reading_room_request
  end

end
