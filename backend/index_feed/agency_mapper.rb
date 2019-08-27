require_relative 'abstract_mapper'

class AgencyMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    solr_doc
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['id'] = obj.id
    whitelisted['uri'] = json.uri
    whitelisted['qsa_id'] = json.qsa_id
    whitelisted['qsa_id_prefixed'] = json.qsa_id_prefixed

    whitelisted['display_string'] = json.title
    whitelisted['abstract'] = json.agency_note
    whitelisted['display_name'] = parse_names([json.display_name]).first
    whitelisted['names'] = parse_names(json.names)
    whitelisted['notes'] = parse_notes(json.notes)
    whitelisted['external_references'] = parse_external_references(json.external_references)
    whitelisted['agent_relationships'] = parse_series_system_rlshps(json.series_system_agent_relationships)
    whitelisted['function_relationships'] = parse_series_system_rlshps(json.series_system_function_relationships)
    whitelisted['mandate_relationships'] = parse_series_system_rlshps(json.series_system_mandate_relationships)

    whitelisted
  end

  def parse_external_references(references)
    references.map{|ref| ref['publish']}
  end

  def parse_names(names)
    names.map do |name|
      {
        'primary_name' => name['primary_name'],
        'accronym' => name['subordinate_name_1'],
        'alternative_name' => name['subordinate_name_2'],
      }
    end
  end
end