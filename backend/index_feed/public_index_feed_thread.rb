require 'pp'
require 'zlib'
require_relative 'indexer_state'

# Previously we were using a regular ArchivesSpace indexer to read
# records from the ArchivesSpace backend and POST them to Public's Solr
# instance.  This won't work in production because we'll have N
# ArchivesSpace instances and M Public instances and we don't want every
# ArchivesSpace instance to have to know about every Public instance's
# Solr.
#
# This indexer is much like the ArchivesSpace periodic indexer (in that
# it wakes up periodically, figures out what's new, pulls out the
# records and Publics them), but it writes to a table in the Public database
# instead of directly to Solr.  That way, Public instances can consume a
# stream of record updates from this new table to bring themselves
# up-to-date.
#
# Mapping records to Solr documents is done here, rather than on the Public
# side, because it seems likely that it'll be easier to schedule a
# restart of ArchivesSpace due to changed indexing rules than to take
# down the Public.  Also, since the Solr documents are quite a bit smaller
# than the JSONModel objects they're derived from, it saves on storage.

class PublicIndexFeedThread

  INDEX_BATCH_SIZE = 25

  MTIME_WINDOW_SECONDS = 30

  RECORD_TYPES = [
    Resource,
    ArchivalObject,
    AgentCorporateEntity,
    DigitalRepresentation,
    PhysicalRepresentation,
    Subject,
  ]

  REPRESENTATION_TYPES = ['physical_representation', 'digital_representation']


  def initialize
    @state = IndexState.new("indexer_plugin_qsa_public_state")
  end

  def call
    loop do
      begin
        run_index_round_with_backoff
      rescue
        Log.error("Error from index_feed_thread: #{$!}")
        Log.exception($!)
      end

      if AppConfig.has_key?(:qsa_public_index_feed_interval_seconds)
        sleep AppConfig[:qsa_public_index_feed_interval_seconds]
      else
        sleep 5
      end
    end
  end

  def run_index_round_with_backoff
    begin
      # Improve our chances of indexers across multiple machines not running in
      # lockstep.  Not that it really matters, but just saves wasted effort.
      sleep (rand * 5)
      run_index_round
    rescue Sequel::DatabaseError => e
      if (e.wrapped_exception && ( e.wrapped_exception.cause or e.wrapped_exception).getSQLState() =~ /^23/)
        # Constraint violations (23*) are expected if we insert a record into
        # the feed at the same time as another node does.  We'll let these roll
        # back the transaction and try again later.
        if ArchivesSpaceService.development?
          Log.info("Exception caught and silently skipped: #{e}")
          Log.exception(e)
        end
      else
        # Something more serious went wrong?
        raise e
      end
    end
  end

  def run_index_round
    # Set the isolation level to READ_COMMITTED so we observe the effects of
    # other concurrent indexer threads (on other machines)
    Repository.each do |repo|
      RECORD_TYPES.each do |record_type|
        now = Time.now
        record_type_name = record_type.name.downcase
        records_added = 0

        PublicDB.open(true, :isolation_level => :committed) do |publicdb|
          last_index_epoch = [(@state.get_last_mtime(repo.id, record_type_name) - MTIME_WINDOW_SECONDS), 0].max
          last_index_time = Time.at(last_index_epoch)

          if last_index_epoch == 0
            # This is a reindex.  We'll do what you'd expect and clear all
            # existing records.  New record will get assigned higher
            # auto-incrementing IDs and the QSA Public will see those as new records
            # and index them again.
            publicdb[:index_feed].filter(:repo_id => repo.id, :record_type => record_type.my_jsonmodel.record_type).delete
          end

          did_something = false

          RequestContext.open(:repo_id => repo.id) do
            record_type
              .this_repo 
              .filter { system_mtime > last_index_time }
              .select(:id, :system_mtime).each_slice(INDEX_BATCH_SIZE) do |id_set|
              start_time = Time.now

              # Other nodes might have got in first on some of these records.
              # And, actually, because we use MTIME_WINDOW_SECONDS to overlap
              # our mtime checks, we might have indexed some of them on a
              # previous run too.  In any case, skip over them.
              uri_set = id_set.map {|row| record_type.uri_for(record_type.my_jsonmodel.record_type, row.id)}

              already_indexed = publicdb[:index_feed].filter(:record_uri => uri_set)
                                  .select(:record_id, :system_mtime)
                                  .map {|row| [row[:record_id], row[:system_mtime]]}
                                  .to_h

              id_set.reject! {|row| already_indexed[row[:id]] && already_indexed[row[:id]] >= row[:system_mtime].to_i}

              if id_set.empty?
                # All records got filtered out, so there's nothing to do.
                next
              end

              records = record_type.filter(:id => id_set.map(&:id)).all

              if records.empty?
                # Shouldn't happen unless things are being deleted out from
                # under us.  But we trust nobody.
                next
              end

              # Delete old versions of the records we're about to index
              records.each do |record|
                publicdb[:index_feed_deletes].filter(:record_uri => record.uri).delete
                publicdb[:index_feed]
                  .filter(:record_uri => record.uri)
                  .filter { system_mtime < record.system_mtime.to_i }
                  .delete
              end

              jsonmodels = record_type.sequel_to_jsonmodel(records)
              jsonmodels.zip(records, map_records(records, jsonmodels)).each do |jsonmodel, sequel_record, mapped|
                if !published?(jsonmodel)
                  begin
                    publicdb[:index_feed_deletes].insert(:record_uri => jsonmodel.uri)
                  rescue Sequel::DatabaseError => e
                    if (e.wrapped_exception && ( e.wrapped_exception.cause or e.wrapped_exception).getSQLState() =~ /^23/)
                      # Constraint violation.  Not a problem.
                    else
                      raise e
                    end
                  end
                else
                  publicdb[:index_feed].insert(:record_type => jsonmodel.jsonmodel_type,
                                            :record_uri => jsonmodel.uri,
                                            :repo_id => repo.id,
                                            :record_id => sequel_record.id,
                                            :system_mtime => sequel_record.system_mtime.to_i,
                                            :blob => Sequel::SQL::Blob.new(gzip(mapped.to_json)))
                end

                did_something = true
              end

              end_time = Time.now

              Log.info("Indexed %d records in %dms (records/second: %.2f)" % [
                         records.count,
                         ((end_time.to_f - start_time.to_f) * 1000).to_i,
                         (records.count / (end_time.to_f - start_time.to_f))
                       ])

              records_added += records.count
            end
          end
        end


        if records_added > 0
          Log.info("Added #{records_added} #{record_type} records to QSA Public index feed")
        end

        @state.set_last_mtime(repo.id, record_type_name, now)
      end
    end

    handle_deletes
  end


  def self.start
    Thread.new do
      PublicIndexFeedThread.new.call
    end
  end


  private

  def handle_deletes
    start = Time.now

    last_mtime = @state.get_last_mtime('_deletes', 'deletes')
    last_delete_epoch = [(@state.get_last_mtime('_deletes', 'deletes') - MTIME_WINDOW_SECONDS), 0].max
    last_delete_time = Time.at(last_delete_epoch)

    did_something = false

    # Using autocommit here since we can happily skip over failed inserts where
    # someone else got in first.
    PublicDB.open(false, :isolation_level => :committed) do |publicdb|
      Tombstone.filter { timestamp >= last_delete_time }.each do |row|
        begin
          publicdb[:index_feed_deletes].insert(:record_uri => row[:uri])
        rescue Sequel::DatabaseError => e
          if (e.wrapped_exception && ( e.wrapped_exception.cause or e.wrapped_exception).getSQLState() =~ /^23/)
            # Constraint violation.  Not a problem.
          else
            raise e
          end
        end
      end
    end

    @state.set_last_mtime('_deletes', 'deletes', start)
  end

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

  def published?(jsonmodel)
    if jsonmodel.has_key?('has_unpublished_ancestor')
      return false if jsonmodel['has_unpublished_ancestor']
    end

    if jsonmodel['jsonmodel_type'] == 'subject'
      return jsonmodel['is_linked_to_published_record']
    end

    jsonmodel['publish']
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

      Log.debug("Generated QSA Public Solr doc:\n#{solr_doc.pretty_inspect}\n")

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

  def gzip(bytestring)
    Zlib::Deflate.deflate(bytestring)
  end

end
