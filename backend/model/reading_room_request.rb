class ReadingRoomRequest < Sequel::Model
  include ASModel
  corresponds_to JSONModel(:reading_room_request)
  set_model_scope :global

  include QSAWWWModel
  qsa_www_table :reading_room_request

  STATUS_AWAITING_AGENCY_APPROVAL = 'AWAITING_AGENCY_APPROVAL'
  STATUS_APPROVED_BY_AGENCY = 'APPROVED_BY_AGENCY'
  STATUS_REJECTED_BY_AGENCY = 'REJECTED_BY_AGENCY'
  STATUS_PENDING = 'PENDING'
  STATUS_IN_RETRIEVAL = 'IN_RETRIEVAL'
  STATUS_READY_FOR_RETRIEVAL = 'READY_FOR_RETRIEVAL'
  STATUS_WITH_RESEARCHER = 'WITH_RESEARCHER'
  STATUS_RETURNED_BY_RESEARCHER = 'RETURNED_BY_RESEARCHER'
  STATUS_COMPLETE = 'COMPLETE'
  STATUS_CANCELLED_BY_QSA = 'CANCELLED_BY_QSA'
  STATUS_CANCELLED_BY_RESEARCHER = 'CANCELLED_BY_RESEARCHER'
  
  VALID_STATUS = [
    STATUS_AWAITING_AGENCY_APPROVAL,
    STATUS_APPROVED_BY_AGENCY,
    STATUS_REJECTED_BY_AGENCY,
    STATUS_PENDING,
    STATUS_IN_RETRIEVAL,
    STATUS_READY_FOR_RETRIEVAL,
    STATUS_WITH_RESEARCHER,
    STATUS_RETURNED_BY_RESEARCHER,
    STATUS_COMPLETE,
    STATUS_CANCELLED_BY_QSA,
    STATUS_CANCELLED_BY_RESEARCHER,
  ]

  READING_ROOM_LOCATION_ENUM_VALUE = 'PSR'
  HOME_LOCATION_ENUM_VALUE = 'HOME'

  STATUSES_TRIGGERING_MOVEMENTS = {
    STATUS_READY_FOR_RETRIEVAL => READING_ROOM_LOCATION_ENUM_VALUE,
    STATUS_COMPLETE => HOME_LOCATION_ENUM_VALUE,
  }


  def update_from_json(json, opts = {}, apply_nested_records = true)
    # opts['modified_time'] = java.lang.System.currentTimeMillis
    # opts['modified_by'] = RequestContext.get(:current_username)

    super
  end

  def self.build_user_map(user_ids)
    PublicDB.open do |db|
      db[:user]
        .filter(:id => user_ids).select(:id, :email, :first_name, :last_name, :verified)
        .map {|row| [row[:id], [:id, :email, :first_name, :last_name, :verified].map {|a| [a, a == :verified ? !(row[a] == 0) : row[a]]}.to_h]}
        .to_h
    end
  end

  def self.sequel_to_jsonmodel(objs, opts = {})
    jsons = super

    users = build_user_map(jsons.map {|request| request['user_id']}.uniq)

    jsons.zip(objs).each do |request, obj|
      request['title'] = "Reading Room Request #{obj.id}"
      request['requested_item'] = {'ref' => request['item_uri']}
      request['requesting_user'] = users.fetch(request['user_id'])
    end

    jsons
  end

  def set_status(status)
    if VALID_STATUS.include?(status)
      PublicDB.open do |db|
        json = self.class.to_jsonmodel(self)

        if json.status == STATUS_AWAITING_AGENCY_APPROVAL
          if status == STATUS_APPROVED_BY_AGENCY
            db[:agency_request_item]
              .filter(:agency_request_id => self.agency_request_id)
              .filter(:item_id => self.item_id)
              .update(:status => 'APPROVED',
                      :modified_time => java.lang.System.currentTimeMillis,
                      :modified_by => RequestContext.get(:current_username))
            status = STATUS_PENDING
          elsif status == STATUS_REJECTED_BY_AGENCY
            db[:agency_request_item]
              .filter(:agency_request_id => self.agency_request_id)
              .filter(:item_id => self.item_id)
              .update(:status => 'REJECTED',
                      :modified_time => java.lang.System.currentTimeMillis,
                      :modified_by => RequestContext.get(:current_username))
          end
        end

        if STATUSES_TRIGGERING_MOVEMENTS.keys.include?(status)
          repo_uri = JSONModel.parse_reference(self.item_uri)[:repository]
          repo_id = JSONModel.parse_reference(repo_uri)[:id]
          RequestContext.open(:repo_id => repo_id) do
            requested_item = PhysicalRepresentation.get_or_die(JSONModel(:physical_representation).id_for(self.item_uri))
            requested_item.move(:context => self.uri,
                                :location => STATUSES_TRIGGERING_MOVEMENTS[status])
          end
        end

        json.status = status
        cleaned = JSONModel(:reading_room_request).from_hash(json.to_hash)
        self.update_from_json(cleaned)
      end
    end
  end

  def self.get_status_map(uris)
    ids = uris.map{|uri| JSONModel(:reading_room_request).id_for(uri)}
    PublicDB.open do |db|
      db[:reading_room_request]
        .filter(:id => ids)
        .select(:id, :status)
        .map {|row| [JSONModel(:reading_room_request).uri_for(row[:id]), row[:status]]}.to_h
    end
  end
end
