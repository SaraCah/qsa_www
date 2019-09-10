require 'set'

class AbstractMapper

  # These get dropped from our whitelisted JSON because they're not interesting
  # to the public app and just add noise.
  UNINTERESTING_PROPERTIES = Set.new([
                                       'lock_version',
                                       'user_mtime',
                                       'system_mtime',
                                       'created_by',
                                       'last_modified_by',
                                       'create_time',
                                     ])

  # These get dropped from keyword searches for the same reason.
  UNINTERESTING_KEYWORD_PROPERTIES = Set.new([
                                               'jsonmodel_type',
                                               'ref',
                                               'relationship_target_record_type',
                                               'relator',
                                               'id',
                                               'uri',
                                               'dates',
                                               'dates_of_existence',
                                               'start_date',
                                               'end_date',
                                               'level',
                                               'external_ids',
                                               'rap_applied',
                                               'rap_attached',
                                             ])


  def initialize(sequel_records, jsonmodels)
    @sequel_records = sequel_records
    @jsonmodels = jsonmodels

    @record_dates = calculate_dates(sequel_records)
  end

  def each
    @sequel_records.zip(@jsonmodels).each do |obj, json|
      if published?(json)
        result = map_record(obj, json, base_solr_doc(obj, json))
        yield(result)
      else
        yield({})
      end
    end
  end

  def map_record(obj, json, solr_doc)
    if @record_dates.fetch(obj.id, false)
      solr_doc['start_date'] = @record_dates.fetch(obj.id).start_date.strftime('%Y-%m-%dT%H:%M:%SZ')
      solr_doc['end_date'] = @record_dates.fetch(obj.id).end_date.strftime('%Y-%m-%dT%H:%M:%SZ')
    end

    if json['rap_applied']
      solr_doc['metadata_closed'] = !json['rap_applied']['open_access_metadata']
      solr_doc['restricted_access'] = json['rap_applied']['access_status'] == 'Restricted Access'
    end

    solr_doc
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
    result = []

    if whitelisted.is_a?(Hash)
      whitelisted.each do |key, val|
        next if UNINTERESTING_KEYWORD_PROPERTIES.include?(key)
        result += parse_keywords(val)
      end
    elsif whitelisted.is_a?(Array)
      result += whitelisted.map {|val| parse_keywords(val)}.flatten(1)
    elsif whitelisted.is_a?(String)
      result += [whitelisted]
    end

    result
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

  def parse_series_system_rlshps(rlshps, filter_by_type = nil, filter_ended = true)
    rlshps.map do |rlshp|
      next if filter_by_type && !ASUtils.wrap(filter_by_type).include?(rlshp['jsonmodel_type'])
      next if filter_ended && rlshp['end_date']

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

  def parse_previous_system_ids(jsonmodel)
    []
  end

  def base_solr_doc(obj, jsonmodel)
    whitelisted = parse_whitelisted_json(obj, jsonmodel)
    drop_uninteresting_properties!(whitelisted)

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
      'json' => ASUtils.to_json(whitelisted),
      'keywords' => parse_keywords(whitelisted),
      'previous_system_ids' => parse_previous_system_ids(jsonmodel),
    }
  end

  def drop_uninteresting_properties!(tree)
    if tree.is_a?(Hash)
      tree.keys.each do |k|
        if UNINTERESTING_PROPERTIES.include?(k)
          tree.delete(k)
        else
          drop_uninteresting_properties!(tree[k])
        end
      end
    elsif tree.is_a?(Array)
      tree.each do |elt|
        drop_uninteresting_properties!(elt)
      end
    else
      # Cool
    end
  end

  def calculate_dates(sequel_records)
    return {} if sequel_records.empty?

    result = sequel_records.map {|obj|
      [obj.id, DateRange.new(DateRange::EPOCH_START_STRING, DateRange::EPOCH_END_STRING)]
    }.to_h

    if sequel_records.fetch(0).is_a?(AgentCorporateEntity)
      # Agencies have dates directly attached.
      ASDate.filter(:agent_corporate_entity_id => sequel_records.map(&:id))
        .select(:agent_corporate_entity_id, :begin, :end)
        .each do |date|
        result[date[:agent_corporate_entity_id]] = result[date[:agent_corporate_entity_id]].parse_and_merge(date[:begin], date[:end])
      end

    elsif sequel_records.fetch(0).is_a?(Resource)
      # Resources do too
      ASDate.filter(:resource_id => sequel_records.map(&:id))
        .select(:resource_id, :begin, :end)
        .each do |date|
        result[date[:resource_id]] = result[date[:resource_id]].parse_and_merge(date[:begin], date[:end])
      end

    elsif sequel_records.fetch(0).is_a?(PhysicalRepresentation) || sequel_records.fetch(0).is_a?(DigitalRepresentation)
      # Representations don't have dates of their own, but they're connected to
      # a record that does.  Or, at least, connected to a record who knows
      # someone that does.
      ao_dates = calculate_dates(ArchivalObject.filter(:id => sequel_records.map(&:archival_object_id)).all)

      sequel_records.each do |representation|
        result[representation.id] = ao_dates.fetch(representation.archival_object_id)
      end

    elsif sequel_records.fetch(0).is_a?(ArchivalObject)
      # Archival Objects either have dates of their own, or inherit them from
      # further up the tree.

      # Map from ID to record
      records_to_process = sequel_records.map {|r| [r.id, r]}.to_h

      # Handle the records with date records attached
      ASDate.filter(:archival_object_id => records_to_process.keys)
        .select(:archival_object_id, :begin, :end)
        .each do |date|
        result[date[:archival_object_id]] = result[date[:archival_object_id]].parse_and_merge(date[:begin], date[:end])
        records_to_process.delete(date[:archival_object_id])
      end

      # Handle records who inherit dates from their parent AO
      parent_dates = calculate_dates(ArchivalObject.filter(:id => records_to_process.values.map {|r| r.parent_id}.compact).all)

      # Handle top-level records who inherit dates from the series
      series_dates = calculate_dates(Resource.filter(:id => records_to_process.values.map {|r| !r.parent_id && r.root_record_id}.compact).all)

      records_to_process.values.each do |ao|
        if ao.parent_id
          result[ao.id] = parent_dates.fetch(ao.parent_id)
        else
          result[ao.id] = series_dates.fetch(ao.root_record_id)
        end
      end

    elsif sequel_records.fetch(0).is_a?(Mandate)
      ASDate.filter(:mandate_id => sequel_records.map(&:id))
        .select(:mandate_id, :begin, :end)
        .each do |date|
        result[date[:mandate_id]] = result[date[:mandate_id]].parse_and_merge(date[:begin], date[:end])
      end

    elsif sequel_records.fetch(0).is_a?(Function)
      ASDate.filter(:function_id => sequel_records.map(&:id))
        .select(:function_id, :begin, :end)
        .each do |date|
        result[date[:function_id]] = result[date[:function_id]].parse_and_merge(date[:begin], date[:end])
      end

    else
      Log.warn("No rule for extracting dates was provided for type: #{sequel_records.fetch(0).class}")
    end

    result
  end

end
