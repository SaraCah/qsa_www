class ReadingRoomRequest < Sequel::Model
  include ASModel
  corresponds_to JSONModel(:reading_room_request)
  set_model_scope :global

  include QSAWWWModel
  qsa_www_table :reading_room_request

  include ItemUses

  STATUS_AWAITING_AGENCY_APPROVAL = 'AWAITING_AGENCY_APPROVAL'
  STATUS_APPROVED_BY_AGENCY = 'APPROVED_BY_AGENCY'
  STATUS_REJECTED_BY_AGENCY = 'REJECTED_BY_AGENCY'
  STATUS_PENDING = 'PENDING'
  STATUS_BEING_RETRIEVED = 'BEING_RETRIEVED'
  STATUS_DELIVERED_TO_READING_ROOM = 'DELIVERED_TO_READING_ROOM'
  STATUS_DELIVERED_TO_ARCHIVIST = 'DELIVERED_TO_ARCHIVIST'
  STATUS_DELIVERED_TO_CONSERVATION = 'DELIVERED_TO_CONSERVATION'
  STATUS_COMPLETE = 'COMPLETE'
  STATUS_CANCELLED_BY_QSA = 'CANCELLED_BY_QSA'
  STATUS_CANCELLED_BY_RESEARCHER = 'CANCELLED_BY_RESEARCHER'
  
  VALID_STATUS = [
    STATUS_AWAITING_AGENCY_APPROVAL,
    STATUS_APPROVED_BY_AGENCY,
    STATUS_REJECTED_BY_AGENCY,
    STATUS_PENDING,
    STATUS_BEING_RETRIEVED,
    STATUS_DELIVERED_TO_READING_ROOM,
    STATUS_DELIVERED_TO_ARCHIVIST,
    STATUS_DELIVERED_TO_CONSERVATION,
    STATUS_COMPLETE,
    STATUS_CANCELLED_BY_QSA,
    STATUS_CANCELLED_BY_RESEARCHER,
  ]

  READING_ROOM_LOCATION_ENUM_VALUE = 'PSR'
  HOME_LOCATION_ENUM_VALUE = 'HOME'
  CONSERVATION_LOCATION_ENUM_VALUE = 'CONS'
  TODESK_LOCATION_ENUM_VALUE = 'TODESK'

  STATUSES_TRIGGERING_MOVEMENTS = {
    STATUS_DELIVERED_TO_READING_ROOM => READING_ROOM_LOCATION_ENUM_VALUE,
    STATUS_COMPLETE => HOME_LOCATION_ENUM_VALUE,
    STATUS_DELIVERED_TO_CONSERVATION => CONSERVATION_LOCATION_ENUM_VALUE,
    STATUS_DELIVERED_TO_ARCHIVIST => TODESK_LOCATION_ENUM_VALUE,
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
    PublicDB.open do |db|
      json = self.class.to_jsonmodel(self)

      if VALID_STATUS.include?(status)
        if status == STATUS_DELIVERED_TO_READING_ROOM
          # Reindex the record in question to encourage its popularity score to be recalculated in the public UI
          rep_parsed = JSONModel.parse_reference(self.item_uri)

          if rep_parsed && rep_parsed[:type] == 'physical_representation'
            DB.open do |db|
              db[:archival_object]
                .filter(:id => db[:physical_representation].filter(:id => rep_parsed[:id]).select(:archival_object_id))
                .update(:system_mtime => Time.now)
            end
          end
        end

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

        parsed_item_uri = JSONModel.parse_reference(self.item_uri)

        if STATUSES_TRIGGERING_MOVEMENTS.keys.include?(status) && parsed_item_uri[:type] == 'physical_representation'
          repo_uri = parsed_item_uri[:repository]
          repo_id = JSONModel.parse_reference(repo_uri)[:id]

          RequestContext.open(:repo_id => repo_id) do
            requested_item = PhysicalRepresentation.get_or_die(parsed_item_uri[:id])
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

  def self.resolve_requested_items(record_uris)
    result = {}

    record_uris
      .map{|uri| JSONModel.parse_reference(uri) }
      .group_by{|parsed| parsed[:type]}
      .each do |jsonmodel_type, parsed_uris|
      ids = parsed_uris.map{|parsed| parsed[:id]}

      model = jsonmodel_type == 'physical_representation' ? PhysicalRepresentation : DigitalRepresentation

      objs = model
               .any_repo
               .filter(:id => ids)
               .all

      objs.group_by{|obj| obj.repo_id}.each do |repo_id, objs|
        RequestContext.open(:repo_id => repo_id) do
          model.sequel_to_jsonmodel(objs).each do |json|
            result[json.uri] = json
          end
        end
      end
    end

    result
  end

  def self.prepare_search_results(search_results)
    uri_to_json = search_results['results']
                    .select{|result| result['primary_type'] == 'reading_room_request'}
                    .map{|result| [result.fetch('uri'), ASUtils.json_parse(result.fetch('json'))]}.to_h

    status_map = get_status_map(uri_to_json.keys)

    requested_item_uris = uri_to_json.values.map{|json| json.fetch('item_uri')}
    resolved_items = resolve_requested_items(requested_item_uris)

    search_results['results'].each do |result|
      next unless result['primary_type'] == 'reading_room_request'
      uri = result.fetch('uri')

      json = uri_to_json.fetch(uri)
      json['status'] = status_map.fetch(uri)
      json['requested_item']['_resolved'] = resolved_items.fetch(json.fetch('item_uri'))
      result['json'] = json.to_json
    end

    search_results
  end

  def self.to_item_uses(json)
    return [] unless json['date_required']

    # only supported on physical representation
    return [] unless JSONModel.parse_reference(json['item_uri'])[:type] == 'physical_representation'

    ru = json['requesting_user']
    used_by = "%s %s <%s>" % [(ru['first_name'] || ru[:first_name]),
                              (ru['last_name'] || ru[:last_name]),
                              (ru['email'] || ru[:email])]

    qsa_id = QSAId.prefixed_id_for(ReadingRoomRequest,
                                   JSONModel.parse_reference(json['uri'])[:id])

    start_date = Time.at(json['date_required']/1000).strftime('%Y-%m-%d')

    JSONModel(:item_use).from_hash({
      'physical_representation' => {'ref' => json['item_uri']},
      'item_use_type' => 'reading_room_request',
      'use_identifier' => qsa_id,
      'status' => json['status'],
      'used_by' => used_by,
      'start_date' => start_date
    })
  end
end
