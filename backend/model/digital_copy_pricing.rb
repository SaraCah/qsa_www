class DigitalCopyPricing < Sequel::Model
  include ASModel
  corresponds_to JSONModel(:digital_copy_pricing)
  set_model_scope :global

  include QSAWWWModel
  qsa_www_table :digital_copy_pricing

  def self.sequel_to_jsonmodel(objs, opts = {})
    jsons = super

    jsons.zip(objs).each do |json, obj|
      json['item'] = {
        'ref' => obj.aspace_record_uri
      }
    end

    jsons
  end

  def self.create_or_update(json)
    make_inactive(json.item['ref'])

    now = Time.now

    DigitalCopyPricing.create(:aspace_record_uri => json.item['ref'],
                              :type => 'record',
                              :price_cents => json.price_cents,
                              :active => 1,
                              :created_by => RequestContext.get(:current_username),
                              :modified_by => RequestContext.get(:current_username),
                              :create_time => java.lang.System.currentTimeMillis,
                              :modified_time => java.lang.System.currentTimeMillis,
                              :system_mtime => now)
  end

  def self.make_inactive(uri)
    DigitalCopyPricing
      .filter(:aspace_record_uri => uri)
      .update(:modified_by => RequestContext.get(:current_username),
              :modified_time => java.lang.System.currentTimeMillis,
              :system_mtime => now,
              :active => 0)
  end
end
