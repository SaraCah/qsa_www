require_relative 'abstract_mapper'

class FunctionMapper < AbstractMapper

  def map_record(obj, json, solr_doc)
    solr_doc
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = super

    whitelisted['id'] = obj.id
    whitelisted['uri'] = json.uri
    whitelisted['qsa_id'] = json.qsa_id
    whitelisted['qsa_id_prefixed'] = json.qsa_id_prefixed

    whitelisted['display_string'] = json.display_string
    whitelisted['title'] = json.title
    whitelisted['source'] = json.source
    whitelisted['note'] = json.note
    whitelisted['date'] = parse_date(json.date)
    whitelisted['function_relationships'] = parse_series_system_rlshps(parse_function_relationships(json.series_system_function_relationships))
    whitelisted['agent_relationships'] = parse_series_system_rlshps(json.series_system_agent_relationships)
    whitelisted['mandate_relationships'] = parse_series_system_rlshps(json.series_system_mandate_relationships)

    whitelisted
  end

  def parse_function_relationships(rlshps)
    rlshps.select{|rlshp| rlshp['jsonmodel_type'] == 'series_system_function_function_containment_relationship'}
  end

  def parse_date(date)
    return if date.nil?

    {
      'begin' => date['begin'],
      'end' => date['end'],
      'certainty' => date['certainty'],
      'certainty_end' => date['certainty_end'],
      'date_notes' => date['date_notes'],
    }
  end
end