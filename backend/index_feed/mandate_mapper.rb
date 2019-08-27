require_relative 'abstract_mapper'

class MandateMapper < AbstractMapper

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
    whitelisted['mandate_type'] = json.mandate_type
    whitelisted['note'] = json.note
    whitelisted['date'] = parse_date(json.date)

    whitelisted['function_relationships'] = parse_series_system_rlshps(json.series_system_function_relationships)
    whitelisted['agent_relationships'] = parse_series_system_rlshps(json.series_system_agent_relationships)
    whitelisted['mandate_relationships'] = parse_series_system_rlshps(json.series_system_mandate_relationships)

    whitelisted
  end

  def parse_date(date)
    return if date.nil?

    {
      'begin' => date['begin'],
      'end' => date['end'],
      'date_notes' => date['date_notes'],
    }
  end

end