require_relative 'agency_mapper'
require_relative 'series_mapper'
require_relative 'item_mapper'
require_relative 'mandate_mapper'
require_relative 'function_mapper'

class PublicIndexerFeedProfile < IndexerFeedProfile

  REPRESENTATION_TYPES = ['physical_representation', 'digital_representation']

  def models_to_index
    [
      Resource,
      ArchivalObject,
      AgentCorporateEntity,
      Mandate,
      Function,
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
    else
      raise "Record type not supported: #{record_model}"
    end
  end


  def index_round_starting
    @repository_published_cache = nil
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
