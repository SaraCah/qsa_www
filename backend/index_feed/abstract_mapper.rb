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
    {}
  end

  def parse_keywords(whitelisted)
    []
  end

  def base_solr_doc(obj, jsonmodel)
    {
      'id' => parse_solr_id(jsonmodel),
      'uri' => jsonmodel['uri'],
      'primary_type' => parse_primary_type(jsonmodel),
      'types' => parse_types(jsonmodel),
      'title' => parse_title(jsonmodel),
      'qsa_id' => parse_qsa_id(jsonmodel),
      'qsa_id_prefixed' => parse_qsa_id_prefixed(jsonmodel),
      'json' => ASUtils.to_json(whitelisted = parse_whitelisted_json(obj, jsonmodel)),
      'keywords' => parse_keywords(whitelisted),
    }
  end

end
