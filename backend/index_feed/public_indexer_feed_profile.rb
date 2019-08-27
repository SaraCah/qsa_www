class PublicIndexerFeedProfile < IndexerFeedProfile

  REPRESENTATION_TYPES = ['physical_representation', 'digital_representation']

  def models_to_index
    [
      Resource,
      ArchivalObject,
      AgentCorporateEntity,
      DigitalRepresentation,
      PhysicalRepresentation,
      Subject,
    ]
  end

  def indexing_interval_seconds
    if AppConfig.has_key?(:qsa_public_index_feed_interval_seconds)
      sleep AppConfig[:qsa_public_index_feed_interval_seconds]
    else
      sleep 5
    end
  end

  def db_open(*opts, &block)
    PublicDB.open do |db|
      block.call(db)
    end
  end

  def record_deleted?(jsonmodel, sequel_record, mapped_record)
    !published?(jsonmodel)
  end

  def published?(jsonmodel)
    if jsonmodel.has_key?('has_unpublished_ancestor')
      return false if jsonmodel['has_unpublished_ancestor']
    end

    if jsonmodel['jsonmodel_type'] == 'subject'
      return jsonmodel['is_linked_to_published_record']
    end

    jsonmodel['publish']
  end

  ## NOTE: All of the following is lifted straight from the MAP indexer.  Do we
  ## need it all?  We might eventually want to pull the commonality into a
  ## shared profile in qsa_kitchensink.

  # Load extra information about the representations in `jsonmodels`
  def load_representation_metadata(sequel_records, jsonmodels)
    return {} unless sequel_records.length > 0 && REPRESENTATION_TYPES.include?(jsonmodels[0].class.record_type)

    metadata_by_ao_id = {}

    archival_objects = ArchivalObject.filter(:id => sequel_records.map(&:archival_object_id)).all

    series_info_by_ao_id = {}

    ArchivalObject
      .join(Resource, Sequel.qualify(:archival_object, :root_record_id) => Sequel.qualify(:resource, :id))
      .filter(Sequel.qualify(:archival_object, :id) => archival_objects.map(&:id))
      .select(Sequel.as(Sequel.qualify(:resource, :id),
                        :resource_id),
              Sequel.qualify(:resource, :repo_id),
              Sequel.qualify(:resource, :title),
              Sequel.as(Sequel.qualify(:archival_object, :id),
                        :ao_id))
    .each do |row|
      series_info_by_ao_id[row[:ao_id]] = {
        :id => row[:resource_id],
        :repo_id => row[:repo_id],
        :title => row[:title],
      }
    end

    archival_objects.zip(ArchivalObject.sequel_to_jsonmodel(archival_objects)).each do |ao, json|
      series = series_info_by_ao_id.fetch(ao.id)

      metadata_by_ao_id[ao.id] = {
        :containing_record_title => json['display_string'],
        :containing_series_title => series.fetch(:title),
        :containing_series_id => JSONModel::JSONModel(:resource).uri_for(series.fetch(:id), :repo_id => series.fetch(:repo_id)),
        :responsible_agency_uri => json['responsible_agency'] ? json['responsible_agency']['ref'] : nil,
        :recent_responsible_agency_refs => json['recent_responsible_agencies'] || [],
        :creating_agency_uri => json['creating_agency'] ? json['creating_agency']['ref'] : nil,
      }
    end

    result = {}

    sequel_records.each do |rec|
      unless metadata_by_ao_id[rec.archival_object_id].nil?
        result[rec.uri] = metadata_by_ao_id[rec.archival_object_id]
      end
    end

    result
  end

  def load_series_metadata(sequel_records, jsonmodels)
    return {} unless sequel_records.length > 0 && ['resource', 'archival_object'].include?(jsonmodels[0].class.record_type)

    result = {}

    if jsonmodels[0].class.record_type == 'archival_object'
      # Need to resolve resource records
      jsonmodels = URIResolver.resolve_references(jsonmodels, ['resource'])
    else
      jsonmodels = jsonmodels.map(&:to_hash)
    end

    jsonmodels.each do |json|
      if json.fetch('jsonmodel_type') == 'resource'
        result[json.fetch('uri')] = {:title => json.fetch('title'), :id => json.fetch('uri')}
      else
        result[json.fetch('uri')] = {:title => json.fetch('resource').fetch('_resolved').fetch('title'), :id => json.fetch('resource').fetch('ref')}
      end
    end

    result
  end


  def build_recent_agency_filter(recent_agencies)
    result = []

    recent_agencies.each do |ref|
      agency_uri = ref['ref']

      date = Date.parse(ref['end_date'])

      90.times do |i|
        result << agency_uri + "_" + (date + i).strftime('%Y-%m-%d')
      end
    end

    result
  end

  # We'll use these values for open-ended ranges.
  EPOCH_START = '0000-01-01T00:00:00Z'
  EPOCH_END = '9999-12-31T23:59:59Z'

  DateRange = Struct.new(:start_date, :end_date) do
    def merge(start_date, end_date)
      if start_date && (self.start_date == EPOCH_START || self.start_date > start_date)
        self.start_date = date_pad_start(start_date)
      end

      if end_date && (self.end_date == EPOCH_END || self.end_date < end_date)
        self.end_date = date_pad_end(end_date)
      end

      self
    end

    def date_pad_start(s)
      default = ['0000', '01', '01']
      bits = s.split('-')

      full_date = (0...3).map {|i| bits.fetch(i, default.fetch(i))}.join('-')

      "#{full_date}T00:00:00Z"
    end

    def date_pad_end(s)
      default = ['9999', '12', '31']
      bits = s.split('-')

      full_date = (0...3).map {|i| bits.fetch(i, default.fetch(i))}.join('-')

      "#{full_date}T23:59:59Z"
    end
  end

  # Return a map from record ID to DateRange
  def calculate_dates(sequel_records)
    return {} if sequel_records.empty?

    result = sequel_records.map {|obj|
      [obj.id, DateRange.new(EPOCH_START, EPOCH_END)]
    }.to_h

    if sequel_records.fetch(0).is_a?(AgentCorporateEntity)
      # Agencies have dates directly attached.
      ASDate.filter(:agent_corporate_entity_id => sequel_records.map(&:id))
        .select(:agent_corporate_entity_id, :begin, :end)
        .each do |date|
        result[date[:agent_corporate_entity_id]] = result[date[:agent_corporate_entity_id]].merge(date[:begin], date[:end])
      end

    elsif sequel_records.fetch(0).is_a?(Resource)
      # Resources do too
      ASDate.filter(:resource_id => sequel_records.map(&:id))
        .select(:resource_id, :begin, :end)
        .each do |date|
        result[date[:resource_id]] = result[date[:resource_id]].merge(date[:begin], date[:end])
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
        result[date[:archival_object_id]] = result[date[:archival_object_id]].merge(date[:begin], date[:end])
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
    else
      Log.warn("No rule for extracting dates was provided for type: #{sequel_records.fetch(0).class}")
    end

    result
  end

  # Map our jsonmodel into something ready for Solr.  All records in the list
  # are guaranteed to be the same type and the list is guaranteed not to be
  # empty.
  def map_records(sequel_records, jsonmodels)
    result = []

    series_metadata = load_series_metadata(sequel_records, jsonmodels)
    representation_metadata = load_representation_metadata(sequel_records, jsonmodels)

    record_dates = calculate_dates(sequel_records)

    jsonmodels.each do |jsonmodel|
      unless published?(jsonmodel)
        result << {}
        next
      end

      solr_doc = {
        'id' => jsonmodel['jsonmodel_type'] + ':' + jsonmodel.id.to_s,
        'uri' => jsonmodel['uri'],
        'primary_type' => jsonmodel['jsonmodel_type'],
        'types' => [jsonmodel['jsonmodel_type']],
        'title' => jsonmodel['display_string'] || jsonmodel['title'],
        'qsa_id' => jsonmodel['qsa_id'] ? jsonmodel['qsa_id'].to_s : nil,
        'qsa_id_prefixed' => jsonmodel['qsa_id_prefixed'],
        'qsaid_sort' => sprintf('%10s', jsonmodel['qsa_id']).gsub(' ', '0'),
        'start_date' => record_dates.fetch(jsonmodel.id).start_date,
        'end_date' => record_dates.fetch(jsonmodel.id).end_date,
      }

      if jsonmodel['jsonmodel_type'] == 'agent_corporate_entity'
        solr_doc['title'] = jsonmodel['display_name']['sort_name']
      end

      if jsonmodel.has_key?('responsible_agency')
        solr_doc['responsible_agency'] = jsonmodel['responsible_agency']['ref']
      end

      if jsonmodel.has_key?('creating_agency')
        solr_doc['creating_agency'] = jsonmodel['creating_agency']['ref']
      end

      if jsonmodel.has_key?('recent_responsible_agencies')
        solr_doc['recent_responsible_agencies'] = jsonmodel['recent_responsible_agencies'].map{|r| r['ref']}
        solr_doc['recent_responsible_agency_filter'] = build_recent_agency_filter(jsonmodel['recent_responsible_agencies'])
      end

      if jsonmodel.has_key?('other_responsible_agencies')
        solr_doc['other_responsible_agencies'] = jsonmodel['other_responsible_agencies'].map{|r| r['ref']}
      end

      if jsonmodel.has_key?('physical_representations')
        solr_doc['physical_representations'] = jsonmodel['physical_representations'].map {|rep| rep['uri']}
        solr_doc['file_issue_allowed'] = jsonmodel['physical_representations'].any?{|rep| rep['file_issue_allowed'] === true}
      end

      if jsonmodel.has_key?('digital_representations')
        solr_doc['digital_representations'] = jsonmodel['digital_representations'].map {|rep| rep['uri']}
        solr_doc['file_issue_allowed'] = jsonmodel['digital_representations'].any?{|rep| rep['file_issue_allowed'] === true}
      end

      solr_doc['physical_representations_count'] = jsonmodel['physical_representations_count']
      solr_doc['digital_representations_count'] = jsonmodel['digital_representations_count']

      if jsonmodel['agency_assigned_id']
        solr_doc['agency_assigned_id'] = jsonmodel['agency_assigned_id']
        solr_doc['agency_assigned_tokens'] = tokenise_id(jsonmodel['agency_assigned_id'])
        solr_doc['agency_sort'] = produce_sort_id(jsonmodel['agency_assigned_id'])
      end

      # Representations get indexed with keywords containing the titles of their
      # containing record & its containing series.
      if REPRESENTATION_TYPES.include?(jsonmodel.class.record_type)
        extra_representation_metadata = representation_metadata.fetch(jsonmodel.uri, {})

        solr_doc['types'] << 'representation'

        solr_doc['keywords'] ||= []

        solr_doc['file_issue_allowed'] = jsonmodel['file_issue_allowed']

        if extra_representation_metadata[:containing_record_title]
          solr_doc['keywords'] << extra_representation_metadata[:containing_record_title]
        end

        if extra_representation_metadata[:containing_series_title]
          solr_doc['series'] = extra_representation_metadata[:containing_series_title]
          solr_doc['keywords'] << extra_representation_metadata[:containing_series_title]
        end

        if extra_representation_metadata[:containing_series_id]
          solr_doc['series_id'] = extra_representation_metadata[:containing_series_id]
        end

        if extra_representation_metadata[:responsible_agency_uri]
          solr_doc['responsible_agency'] = extra_representation_metadata[:responsible_agency_uri]
        end

        if extra_representation_metadata[:recent_responsible_agency_refs]
          solr_doc['recent_responsible_agency_filter'] = build_recent_agency_filter(extra_representation_metadata[:recent_responsible_agency_refs])
        end

        if extra_representation_metadata[:creating_agency_uri]
          solr_doc['creating_agency'] = extra_representation_metadata[:creating_agency_uri]
        end

        solr_doc['current_location'] = jsonmodel['current_location']

      end

      if solr_doc['title']
        solr_doc['title_sort'] = solr_doc['title'].downcase
      end

      result << solr_doc
    end

    result
  end

  # Produce as many tokens as might be useful from a given ID
  def tokenise_id(s)
    result = [s]

    # Split on common separators
    result.concat(s.split(/[\-\._\/\\]/))

    # Runs of letters & numbers
    result.concat(s.scan(/([A-Za-z]+|[0-9]+)/).flatten)

    result.uniq!
    result
  end

  # Produce a sort key that will sort our identifiers in a way that "feels"
  # right, whatever that means.
  #
  # Currently what that means is that common non-numeric prefixes tend to
  # cluster, and the numeric bits end up sorted numerically and not
  # lexicographically.
  #
  def produce_sort_id(s)
    s.scan(/([A-Za-z]+|[0-9]+)/)
      .flatten
      .map {|s|
      pad = s[0] =~ /^[0-9]/ ? '0' : '!'
      sprintf('%10s', s).gsub(' ', pad)
    }.join('')
  end

end
