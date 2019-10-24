class DigitalCopyPricing < Sequel::Model
  include ASModel
  corresponds_to JSONModel(:digital_copy_pricing)
  set_model_scope :global

  include QSAWWWModel
  qsa_www_table :digital_copy_pricing

  def self.sequel_to_jsonmodel(objs, opts = {})
    jsons = super

    record_data = build_record_data_map(objs)

    jsons.zip(objs).each do |json, obj|
      json['item'] = {
        'ref' => obj.aspace_record_uri,
        'qsa_id_prefixed' => record_data.fetch(obj.aspace_record_uri).fetch(:qsa_id_prefixed),
        'display_string' => record_data.fetch(obj.aspace_record_uri).fetch(:display_string),
      }
    end

    jsons
  end

  def self.build_record_data_map(objs)
    result = {}

    record_uris = objs.map(&:aspace_record_uri)
    grouped = record_uris.map{|uri| JSONModel.parse_reference(uri)}.group_by{|reference| reference[:type]}

    grouped.each do |record_type, references|
      if record_type == 'resource'
        Resource
          .any_repo
          .filter(:id => references.map{|reference| reference[:id]})
          .select(:id, :repo_id, :title, :qsa_id)
          .each do |row|
          uri = JSONModel(:resource).uri_for(row[:id], :repo_id => row[:repo_id])
          result[uri] = {
            :display_string => row[:title],
            :qsa_id_prefixed => QSAId.prefixed_id_for(Resource, row[:qsa_id])
          }
        end
      elsif record_type == 'archival_object'
        ArchivalObject
          .any_repo
          .filter(:id => references.map{|reference| reference[:id]})
          .select(:id, :repo_id, :display_string, :qsa_id)
          .each do |row|
          uri = JSONModel(:archival_object).uri_for(row[:id], :repo_id => row[:repo_id])
          result[uri] = {
            :display_string => row[:display_string],
            :qsa_id_prefixed => QSAId.prefixed_id_for(ArchivalObject, row[:qsa_id])
          }
        end
      end
    end

    result
  end

  def self.create_or_update(json)
    make_inactive(json.item['ref'])

    DigitalCopyPricing.create(:aspace_record_uri => json.item['ref'],
                              :type => 'record',
                              :price_cents => json.price_cents,
                              :active => 1,
                              :created_by => RequestContext.get(:current_username),
                              :modified_by => RequestContext.get(:current_username),
                              :create_time => java.lang.System.currentTimeMillis,
                              :modified_time => java.lang.System.currentTimeMillis,
                              :system_mtime => Time.now)
  end

  def self.make_inactive(uri)
    DigitalCopyPricing
      .filter(:aspace_record_uri => uri)
      .update(:modified_by => RequestContext.get(:current_username),
              :modified_time => java.lang.System.currentTimeMillis,
              :system_mtime => Time.now,
              :active => 0)
  end
end
