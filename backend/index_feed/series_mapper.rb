require_relative 'abstract_mapper'

class SeriesMapper < AbstractMapper

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
    whitelisted['title'] = json.title
    whitelisted['sensitivity_label'] = json.sensitivity_label
    whitelisted['dates'] = parse_dates(json.dates)
    whitelisted['subjects'] = parse_subjects(json.subjects)
    whitelisted['notes'] = parse_notes(json.notes)
    whitelisted['series_relationships'] = parse_series_system_rlshps(json.series_system_series_relationships, ['series_system_series_series_association_relationship', 'series_system_series_series_ownership_relationship', 'series_system_series_series_succession_relationship'])
    whitelisted['agent_relationships'] = parse_series_system_rlshps(parse_agent_rlshps(json.series_system_agent_relationships))
    whitelisted['mandate_relationships'] = parse_series_system_rlshps(json.series_system_mandate_relationships, 'series_system_mandate_series_documentation_relationship')
    whitelisted['function_relationships'] = parse_series_system_rlshps(json.series_system_function_relationships, 'series_system_function_series_documentation_relationship')
    whitelisted['rap_attached'] = parse_rap(json.rap_attached)

    whitelisted
  end

  def parse_notes(notes)
    super.select{|note| supported_note?(note)}
  end

  def supported_note?(note_json)
    jsonmodel_type = note_json.fetch('jsonmodel_type')
    type = note_json['type']

    if jsonmodel_type == 'note_multipart' && type
      return ['arrangement', 'prefercite'].include?(type)
    end

    if jsonmodel_type == 'note_singlepart' && type
      return ['abstract'].include?(type)
    end

    return false
  end

end