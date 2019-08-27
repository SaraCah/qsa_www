require_relative 'abstract_mapper'

class ItemMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    solr_doc
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['id'] = obj.id
    whitelisted['uri'] = json.uri
    whitelisted['qsa_id'] = json.qsa_id
    whitelisted['qsa_id_prefixed'] = json.qsa_id_prefixed

    whitelisted['parent'] = json.parent
    whitelisted['resource'] = json.resource

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

    whitelisted['agent_relationships'] = parse_series_system_rlshps(json.series_system_agent_relationships)
    whitelisted['responsible_agency'] = json.responsible_agency
    whitelisted['creating_agency'] = json.creating_agency

    whitelisted['rap_applied'] = parse_rap(json.rap_applied)

    whitelisted['digital_representations'] = parse_representations(json.digital_representations)
    whitelisted['physical_representations'] = parse_representations(json.physical_representations)

    whitelisted
  end

  def parse_representations(representations)
    representations.map do |representation|
      {
        'ref' => representation['uri'],
      }
    end
  end

  def published?(jsonmodel)
    return false if jsonmodel['has_unpublished_ancestor']

    super
  end
end