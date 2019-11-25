require_relative 'agency_mapper'
require_relative 'series_mapper'
require_relative 'item_mapper'
require_relative 'mandate_mapper'
require_relative 'function_mapper'
require_relative 'representation_mapper'

class PublicIndexerFeedProfile < IndexerFeedProfile

  REPRESENTATION_TYPES = ['physical_representation', 'digital_representation']

  def models_to_index
    [
      Resource,
      ArchivalObject,
      AgentCorporateEntity,
      Mandate,
      Function,
      PhysicalRepresentation,
      DigitalRepresentation,
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
    PublicDB.open(*opts) do |db|
      block.call(db)
    end
  end

  def record_deleted?(jsonmodel, sequel_record, mapped_record)
    if sequel_record.class.model_scope(true) == :repository
      return true if !repository_published?(sequel_record.repo_id)
    end

    mapped_record.empty?
  end

  # Map our jsonmodel into something ready for Solr.  All records in the list
  # are guaranteed to be the same type and the list is guaranteed not to be
  # empty.
  def map_records(sequel_records, jsonmodels)
    record_model = sequel_records.first.class

    if record_model == Resource
      SeriesMapper.new(sequel_records, jsonmodels)
    elsif record_model == ArchivalObject
      ItemMapper.new(sequel_records, jsonmodels)
    elsif record_model == AgentCorporateEntity
      AgencyMapper.new(sequel_records, jsonmodels)
    elsif record_model == Mandate
      MandateMapper.new(sequel_records, jsonmodels)
    elsif record_model == Function
      FunctionMapper.new(sequel_records, jsonmodels)
    elsif [PhysicalRepresentation, DigitalRepresentation].include?(record_model)
      RepresentationMapper.new(sequel_records, jsonmodels)
    else
      raise "Record type not supported: #{record_model}"
    end
  end

  def index_round_starting
    @repository_published_cache = nil
  end

  def updates_for_model(db, model_dataset, model, last_index_time)
    super

    # We want to update any record that has had a tag added/updated since we
    # last checked.
    additional_records =
      if model.has_jsonmodel?
        record_type = model.my_jsonmodel.record_type

        # Cripes.  last_index_time is a ruby Time; record_tag.modified_time is
        # milliseconds since epoch; system_mtime is seconds since epoch.
        # TMTWWTDI I suppose!
        PublicDB.open do |public_db|
          result = public_db[:record_tag]
            .filter(:record_type => record_type)
            .where { modified_time >= (last_index_time.to_i * 1000) }
            .select(:record_id, :modified_time)
            .map {|row|
            {
              :id => Integer(row[:record_id].split(/:/).last),
              :system_mtime => row[:modified_time] / 1000,
            }
          }

          # Fun complication: representation tags get indexed into their parent AO, so
          # we need to reindex the corresponding AO when a representation is tagged.
          if model == ArchivalObject

            # {'physical_representation' => [{record_id: 'physical_representation:123',
            #                                 record_type: 'physical_representation',
            #                                 modified_time: 1573172924333} ...]}
            tagged_representations_by_type =
              public_db[:record_tag]
                .filter(:record_type => ['physical_representation', 'digital_representation'])
                .where { modified_time >= (last_index_time.to_i * 1000) }
                .select(:record_id, :record_type, :modified_time)
                .all
                .group_by {|row| row[:record_type]}

            # the extra AOs we need to index mapped to the mtime we'll report
            # back (we take the mtime of when the tag was added, not the mtime
            # of the record itself)
            aos_to_reindex = {}

            [:physical_representation, :digital_representation].each do |representation|
              # representation_id -> tag mtime
              representation_tag_mtime = tagged_representations_by_type
                                           .fetch(representation.to_s, [])
                                           .map {|row| [
                                                   Integer(row[:record_id].split(':').last),
                                                   row[:modified_time]
                                                 ]}
                                           .to_h

              model_dataset.db[representation]
                .filter(:id => representation_tag_mtime.keys)
                .select(:id, :archival_object_id)
                .each do |row|
                aos_to_reindex[row[:archival_object_id]] = representation_tag_mtime.fetch(row[:id])
              end
            end

            result += aos_to_reindex.map {|id, system_mtime| {id: id, system_mtime: system_mtime / 1000}}
            result.uniq!
          end

          result
        end
      else
        []
      end


    # Public DB isn't repo aware, so we need to drop any records that aren't in
    # scope for the current dataset.
    records_in_active_repo =
      Set.new(model_dataset.filter(:id => additional_records.map {|rec| rec[:id]})
                .select(:id)
                .map {|row| row[:id]})

    yield additional_records.select {|rec| records_in_active_repo.include?(rec[:id])}.uniq {|rec| rec[:id]}

    :updates_for_model
  end

  private

  def repository_published?(repo_id)
    @repository_published_cache ||= {}

    unless @repository_published_cache.has_key?(repo_id)
      Repository
        .filter(:id => repo_id)
        .select(:id, :publish)
        .each do |row|
        @repository_published_cache[row[:id]] = row[:publish] == 1
      end
    end

    @repository_published_cache.fetch(repo_id)
  end
end
