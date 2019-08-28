require_relative 'abstract_mapper'

class RepresentationMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    solr_doc
  end

  def published?(jsonmodel)
    return false if jsonmodel['has_unpublished_ancestor']

    super
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

end