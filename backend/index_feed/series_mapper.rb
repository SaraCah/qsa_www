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

    whitelisted['title'] = json.title
    whitelisted['sensitivity_label'] = json.sensitivity_label
    whitelisted['dates'] = json.dates
    whitelisted['notes'] = parse_notes(json.notes)
    whitelisted['series_relationships'] = json.series_system_series_relationships
    whitelisted['agent_relationships'] = parse_series_system_rlshps(parse_agent_rlshps(json.series_system_agent_relationships))
    whitelisted['mandate_relationships'] = parse_series_system_rlshps(json.series_system_mandate_relationships)
    whitelisted['function_relationships'] = parse_series_system_rlshps(json.series_system_function_relationships)
    whitelisted['function_relationships'] = parse_series_system_rlshps(json.series_system_function_relationships)
    whitelisted['rap_attached'] = json.rap_attached

    whitelisted
  end

  def parse_notes(notes_json)
    notes_json.select{|note| note['publish'] && supported_note?(note)}
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

  def parse_agent_rlshps(rlshps)
    rlshps.select do |rlshp|
      if rlshp['jsonmodel_type'] == 'series_system_agent_record_ownership_relationship'
        rlshp['end_date'].nil?
      else
        rlshp['jsonmodel_type'] == 'series_system_agent_record_creation_relationship'
      end
    end
  end

  def parse_series_system_rlshps(rlshps)
    rlshps.map do |rlshp|
      {
        'jsonmodel_type' => rlshp['jsonmodel_type'],
        'relationship_target_record_type' => rlshp['relationship_target_record_type'],
        'ref' => rlshp['ref'],
        'relator' => rlshp['relator'],
        'start_date' => rlshp['start_date'],
        'end_date' => rlshp['end_date'],
      }
    end
  end
end