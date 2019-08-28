class AbstractMapper

  def initialize(sequel_records, jsonmodels)
    @sequel_records = sequel_records
    @jsonmodels = jsonmodels
  end

  def each
    @sequel_records.zip(@jsonmodels).each do |obj, json|
      if published?(json)
        yield(map_record(obj, json, base_solr_doc(obj, json)))
      else
        yield({})
      end
    end
  end

  def map_record(obj, json, solr_doc)
    raise "implement me"
  end

  protected

  def published?(jsonmodel)
    jsonmodel['publish']
  end

  def parse_solr_id(jsonmodel)
    jsonmodel['jsonmodel_type'] + ':' + jsonmodel.id.to_s
  end

  def parse_title(jsonmodel)
    jsonmodel['display_string'] || jsonmodel['title']
  end

  def parse_qsa_id(jsonmodel)
    jsonmodel['qsa_id'] ? jsonmodel['qsa_id'].to_s : nil
  end

  def parse_qsa_id_prefixed(jsonmodel)
    jsonmodel['qsa_id_prefixed']
  end

  def parse_qsa_id_sort(jsonmodel)
    return nil unless jsonmodel['qsa_id']

    sprintf('%10s', jsonmodel['qsa_id']).gsub(' ', '0')
  end

  def parse_primary_type(jsonmodel)
    jsonmodel['jsonmodel_type']
  end

  def parse_types(jsonmodel)
    [parse_primary_type(jsonmodel)]
  end

  def parse_whitelisted_json(obj, json)
    whitelisted = {}
    whitelisted['id'] = parse_solr_id(json)
    whitelisted['uri'] = json.uri
    whitelisted['jsonmodel_type'] = json['jsonmodel_type']
    whitelisted
  end

  def parse_keywords(whitelisted)
    []
  end

  def parse_rap(rap)
    rap
  end

  def parse_notes(notes)
    notes.select{|note| note['publish']}
  end

  def parse_external_documents(docs)
    docs.select{|doc| doc['publish']}
  end

  def parse_dates(dates)
    dates
  end

  def parse_external_ids(external_ids)
    external_ids
  end

  def parse_subjects(subjects)
    subjects.map do |subject|
      {
        'ref' => subject['ref'],
      }
    end
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

  def parse_series_system_rlshps(rlshps, filter_by_type = nil)
    rlshps.map do |rlshp|
      next if filter_by_type && !ASUtils.wrap(filter_by_type).include?(rlshp['jsonmodel_type'])

      {
        'jsonmodel_type' => rlshp['jsonmodel_type'],
        'relationship_target_record_type' => rlshp['relationship_target_record_type'],
        'ref' => rlshp['ref'],
        'relator' => rlshp['relator'],
        'start_date' => rlshp['start_date'],
        'end_date' => rlshp['end_date'],
      }
    end.compact
  end

  def base_solr_doc(obj, jsonmodel)
    {
      'id' => parse_solr_id(jsonmodel),
      'uri' => jsonmodel['uri'],
      'primary_type' => parse_primary_type(jsonmodel),
      'types' => parse_types(jsonmodel),
      'title' => parse_title(jsonmodel),
      'title_sort' => parse_title(jsonmodel).downcase,
      'qsa_id' => parse_qsa_id(jsonmodel),
      'qsa_id_prefixed' => parse_qsa_id_prefixed(jsonmodel),
      'qsaid_sort' => parse_qsa_id_sort(jsonmodel),
      'json' => ASUtils.to_json(whitelisted = parse_whitelisted_json(obj, jsonmodel)),
      'keywords' => parse_keywords(whitelisted),
    }
  end

end
