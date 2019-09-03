require_relative 'abstract_mapper'

class RepresentationMapper < AbstractMapper

  def initialize(sequel_records, jsonmodels)
    super

    @linked_agents_publish_map = build_linked_agents_publish_map
  end

  def published?(jsonmodel)
    return false if jsonmodel['has_unpublished_ancestor']

    super && agency_published?(jsonmodel.responsible_agency)
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

    if agency_published?(json.responsible_agency)
      agency_id = JSONModel::JSONModel(:agent_corporate_entity).id_for(json.responsible_agency.fetch('ref'))
      solr_doc['responsible_agency_id'] = "agent_corporate_entity:#{agency_id}"
    end

    solr_doc
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['qsa_id'] = json.qsa_id
    whitelisted['qsa_id_prefixed'] = json.qsa_id_prefixed

    whitelisted['controlling_record'] = json.controlling_record

    whitelisted['display_string'] = json.display_string
    whitelisted['title'] = json.title
    whitelisted['description'] = json.description
    whitelisted['agency_assigned_id'] = json.agency_assigned_id
    whitelisted['external_ids'] = parse_external_ids(json.external_ids)

    whitelisted['intended_use'] = json.intended_use

    whitelisted['rap_applied'] = parse_rap(json.rap_applied)

    whitelisted
  end

  def build_linked_agents_publish_map
    result = {}
    agency_ids = []
    @jsonmodels.each do |json|
      agency_ids << JSONModel::JSONModel(:agent_corporate_entity).id_for(json['responsible_agency']['ref']) if json['responsible_agency']
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