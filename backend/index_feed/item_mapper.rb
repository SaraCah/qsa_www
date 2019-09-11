require_relative 'abstract_mapper'

class ItemMapper < AbstractMapper

  def initialize(sequel_records, jsonmodels)
    super

    @linked_agents_publish_map = build_linked_agents_publish_map
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
    solr_doc['position'] = json.position

    if agency_published?(json.creating_agency)
      agency_id = JSONModel::JSONModel(:agent_corporate_entity).id_for(json.creating_agency.fetch('ref'))
      solr_doc['creating_agency_id'] = "agent_corporate_entity:#{agency_id}"
    end

    if agency_published?(json.responsible_agency)
      agency_id = JSONModel::JSONModel(:agent_corporate_entity).id_for(json.responsible_agency.fetch('ref'))
      solr_doc['responsible_agency_id'] = "agent_corporate_entity:#{agency_id}"
    end

    solr_doc['has_digital_representations'] = parse_digital_representations(json).length > 0
    solr_doc['has_physical_representations'] = parse_physical_representations(json).length > 0

    solr_doc
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['qsa_id'] = json.qsa_id
    whitelisted['qsa_id_prefixed'] = json.qsa_id_prefixed

    whitelisted['ancestors'] = json.ancestors
    whitelisted['parent'] = json.parent
    whitelisted['resource'] = json.resource
    whitelisted['position'] = json.position

    whitelisted['display_string'] = json.display_string
    whitelisted['title'] = json.title
    whitelisted['description'] = json.description
    whitelisted['sensitivity_label'] = json.sensitivity_label
    whitelisted['agency_assigned_id'] = json.agency_assigned_id
    whitelisted['external_ids'] = parse_external_ids(json.external_ids)

    whitelisted['dates'] = parse_dates(json.dates)
    whitelisted['subjects'] = parse_subjects(json.subjects)

    whitelisted['notes'] = parse_notes(json.notes)

    whitelisted['external_documents'] = parse_external_documents(json.external_documents)
    whitelisted['agent_relationships'] = parse_series_system_rlshps(parse_agent_rlshps(json.series_system_agent_relationships), nil, false)
    whitelisted['responsible_agency'] = json.responsible_agency
    whitelisted['creating_agency'] = json.creating_agency

    whitelisted['rap_applied'] = parse_rap(json.rap_applied)
    whitelisted['rap_expiration'] = json.rap_expiration

    whitelisted['digital_representations'] = parse_digital_representations(json)
    whitelisted['physical_representations'] = parse_physical_representations(json)

    whitelisted
  end

  def parse_digital_representations(json)
    json.digital_representations.map do |representation|
      next unless representation_published?(representation, json)

      whitelisted = parse_representation(representation)
      whitelisted['file_size'] = representation['file_size']
      whitelisted['file_type'] = representation['file_type']
      whitelisted
    end.compact
  end

  def parse_physical_representations(json)
    json.physical_representations.map do |representation|
      next unless representation_published?(representation, json)

      whitelisted = parse_representation(representation)
      whitelisted['format'] = representation['format']
      whitelisted
    end.compact
  end

  def parse_representation(json)
    whitelisted = {}

    whitelisted['qsa_id'] = json['qsa_id']
    whitelisted['qsa_id_prefixed'] = json['qsa_id_prefixed']

    whitelisted['display_string'] = json['display_string']
    whitelisted['title'] = json['title']
    whitelisted['description'] = json['description']
    whitelisted['agency_assigned_id'] = json['agency_assigned_id']
    whitelisted['external_ids'] = parse_external_ids(json['external_ids'])

    whitelisted['intended_use'] = json['intended_use']

    whitelisted['rap_applied'] = parse_rap(json['rap_applied'])

    whitelisted
  end

  def representation_published?(representation, item)
    representation['publish'] == true
  end

  def parse_previous_system_ids(json)
    super + [json.repository_processing_note].compact
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
end