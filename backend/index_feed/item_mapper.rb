require_relative 'abstract_mapper'

class ItemMapper < AbstractMapper

  def initialize(sequel_records, jsonmodels)
    super

    @resources_map = build_resources_map
    @linked_agents_publish_map = build_linked_agents_publish_map
    @subjects_map = build_subjects_map
  end

  def published?(jsonmodel)
    return false if jsonmodel['has_unpublished_ancestor']

    super && agency_published?(jsonmodel['responsible_agency'])
  end

  def agency_published?(agency_ref)
    if agency_ref && agency_ref['ref']
      agency_id = JSONModel::JSONModel(:agent_corporate_entity).id_for(agency_ref['ref'])
      return @linked_agents_publish_map.fetch(agency_id)
    end

    return false
  end

  def map_record(obj, json, solr_doc)
    super

    if json.parent
      id = JSONModel::JSONModel(:archival_object).id_for(json.parent.fetch('ref'))
      solr_doc['parent_id'] = "archival_object:#{id}"
    else
      id = JSONModel::JSONModel(:resource).id_for(json.resource.fetch('ref'))
      solr_doc['parent_id'] = "resource:#{id}"
    end

    resource_id = JSONModel::JSONModel(:resource).id_for(json.resource.fetch('ref'))
    solr_doc['resource_id'] = "resource:#{resource_id}"

    solr_doc['position'] = json.position

    if agency_published?(json.creating_agency)
      agency_id = JSONModel::JSONModel(:agent_corporate_entity).id_for(json.creating_agency.fetch('ref'))
      solr_doc['creating_agency_id'] = "agent_corporate_entity:#{agency_id}"
    end

    if agency_published?(json.responsible_agency)
      agency_id = JSONModel::JSONModel(:agent_corporate_entity).id_for(json.responsible_agency.fetch('ref'))
      solr_doc['responsible_agency_id'] = "agent_corporate_entity:#{agency_id}"
    end

    parsed_digital = parse_digital_representations(json)
    parsed_physical = parse_physical_representations(json)

    solr_doc['tags'] = tags_from_representations(parsed_physical + parsed_digital)

    solr_doc['digital_representation_count'] = parsed_digital.length
    solr_doc['has_digital_representations'] = solr_doc['digital_representation_count'] > 0
    solr_doc['physical_representation_count'] = parsed_physical.length
    solr_doc['has_physical_representations'] = solr_doc['physical_representation_count'] > 0

    solr_doc
  end

  def tags_from_representations(representations)
    representation_tags_by_solr_id = {}

    PublicDB.open do |public_db|
      public_db[:record_tag]
        .filter(:deleted => 0)
        .filter(:record_id => representations.map {|record| record['id']}.compact)
        .select(:record_id, :tag)
        .each do |row|
        representation_tags_by_solr_id[row[:record_id]] ||= []
        representation_tags_by_solr_id[row[:record_id]] << row[:tag]
      end
    end

    representations.flat_map {|record|
      representation_tags_by_solr_id.fetch(record['id'], [])
    }
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['qsa_id'] = json.qsa_id
    whitelisted['qsa_id_prefixed'] = json.qsa_id_prefixed

    whitelisted['ancestors'] = json.ancestors
    whitelisted['parent'] = json.parent
    whitelisted['resource'] = parse_resource(json.resource)
    whitelisted['position'] = json.position

    whitelisted['display_string'] = json.display_string
    whitelisted['title'] = json.title
    whitelisted['description'] = json.description
    whitelisted['sensitivity_label'] = I18n.t("enumerations.runcorn_sensitivity_label.#{json.sensitivity_label}", default: json.sensitivity_label)
    whitelisted['copyright_status'] = I18n.t("enumerations.runcorn_copyright_status.#{json.copyright_status}", default: json.copyright_status)
    whitelisted['agency_assigned_id'] = json.agency_assigned_id
    whitelisted['external_ids'] = parse_external_ids(json.external_ids)

    whitelisted['dates'] = parse_dates(json.dates)
    whitelisted['subjects'] = parse_subjects(json.subjects)

    whitelisted['notes'] = parse_notes(json.notes)

    whitelisted['external_documents'] = parse_external_documents(json.external_documents)
    whitelisted['agent_relationships'] = parse_series_system_rlshps(parse_agent_rlshps(json.series_system_agent_relationships), nil, false)
    whitelisted['item_relationships'] = parse_series_system_rlshps(json.series_system_item_relationships, ['series_system_item_item_containment_relationship', 'series_system_item_item_succession_relationship'], false)
    whitelisted['responsible_agency'] = json.responsible_agency
    whitelisted['creating_agency'] = json.creating_agency

    whitelisted['rap_applied'] = parse_rap(json.rap_applied)
    whitelisted['rap_access_status'] = json.rap_access_status
    whitelisted['rap_expiration'] = json.rap_expiration

    whitelisted['digital_representations'] = parse_digital_representations(json)
    whitelisted['physical_representations'] = parse_physical_representations(json)

    whitelisted['previous_system_ids'] = parse_previous_system_ids(json)

    whitelisted
  end

  def parse_subjects(subjects)
    subjects.map do |subject|
      @subjects_map.fetch(subject.fetch('ref'))
    end
  end

  def parse_resource(resource_ref)
    uri = resource_ref.fetch('ref')
    resource_obj = @resources_map.fetch(uri)

    {
      'ref' => uri,
      'qsa_id_prefixed' => QSAId.prefixed_id_for(Resource, resource_obj.qsa_id),
      'display_string' => resource_obj.title,
    }
  end

  def parse_description(jsonmodel)
    jsonmodel['description']
  end

  RepresentationRef = Struct.new(:id)

  def parse_physical_representations(json)
    mapper = RepresentationMapper.new([], [])

    Array(json['physical_representations']).map {|representation|
      next unless mapper.published?(representation)

      representation_id = JSONModel::JSONModel(:physical_representation).id_for(representation.fetch('uri'))
      mapper.parse_whitelisted_json(RepresentationRef.new(representation_id),
                                    JSONModel::JSONModel(:physical_representation).from_hash(representation, raise_errors = false, trusted = true))
    }.compact
  end

  def parse_digital_representations(json)
    mapper = RepresentationMapper.new([], [])

    Array(json['digital_representations']).map {|representation|
      next unless mapper.published?(representation)

      representation_id = JSONModel::JSONModel(:digital_representation).id_for(representation.fetch('uri'))
      mapper.parse_whitelisted_json(RepresentationRef.new(representation_id),
                                    JSONModel::JSONModel(:digital_representation).from_hash(representation, raise_errors = false, trusted = true))
    }.compact
  end


  def parse_previous_system_ids(json)
    super + json.previous_system_identifiers.to_s.split("\n").map{|s| s.strip}.reject{|s| s.empty?}
  end

  def build_linked_agents_publish_map
    result = {}
    agency_ids = []
    @jsonmodels.each do |json|
      agency_ids << JSONModel::JSONModel(:agent_corporate_entity).id_for(json['responsible_agency']['ref']) if json['responsible_agency']
      agency_ids << JSONModel::JSONModel(:agent_corporate_entity).id_for(json['creating_agency']['ref']) if json['creating_agency']
    end

    DB.open do |db|
      db[:agent_corporate_entity]
        .filter(:id => agency_ids)
        .select(:id, :publish)
        .each do |row|
        result[row[:id]] = row[:publish] == 1
      end
    end

    result
  end

  def build_resources_map
    result = {}

    resource_ids = @jsonmodels.map do |json|
      JSONModel.parse_reference(json.resource.fetch('ref'))[:id]
    end

    DB.open do |db|
      Resource
        .filter(:id => resource_ids)
        .map {|obj|
          result[obj.uri] = obj
        }
    end

    result
  end

  def build_subjects_map
    subject_uris = []

    @jsonmodels.each do |json|
      subject_uris += json['subjects'].map{|subject| subject['ref']}
    end

    subject_ids = subject_uris.map{|uri| JSONModel::JSONModel(:subject).id_for(uri)}

    result = {}

    DB.open do |db|
      Subject
        .filter(:id => subject_ids)
        .select(:id, :title)
        .map do |row|
        result[JSONModel::JSONModel(:subject).uri_for(row[:id])] = row[:title]
      end
    end

    result
  end
end
