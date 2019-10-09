class ReadingRoomRequest < Sequel::Model
  include ASModel
  corresponds_to JSONModel(:reading_room_request)
  set_model_scope :global

  include QSAWWWModel
  qsa_www_table :reading_room_request


  def self.sequel_to_jsonmodel(objs, opts = {})
    jsons = super

    jsons.each do |request|
      request['requested_item'] = {'ref' => request['item_uri']}
    end
  end
end
