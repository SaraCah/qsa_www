class ReadingRoomRequest < Sequel::Model
  include ASModel
  corresponds_to JSONModel(:reading_room_request)
  set_model_scope :global

  include QSAWWWModel
  qsa_www_table :reading_room_request


  def self.build_user_map(user_ids)
    PublicDB.open do |db|
      db[:user]
        .filter(:id => user_ids).select(:id, :email, :first_name, :last_name)
        .map {|row| [row[:id], [:id, :email, :first_name, :last_name].map {|a| [a, row[a]]}.to_h]}
        .to_h
    end
  end

  def self.sequel_to_jsonmodel(objs, opts = {})
    jsons = super

    users = build_user_map(jsons.map {|request| request['user_id']}.uniq)

    jsons.each do |request|
      request['requested_item'] = {'ref' => request['item_uri']}
      request['requesting_user'] = users.fetch(request['user_id'])
    end
  end
end
