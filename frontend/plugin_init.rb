ArchivesSpace::Application.extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))


Rails.application.config.after_initialize do
  Plugins.add_search_facets(:reading_room_request, "primary_type")
  Plugins.add_search_facets(:reading_room_request, "rrr_status_u_ssort")
  Plugins.add_facet_group_i18n("rrr_status_u_ssort",
                               proc {|facet| "reading_room_request.statuses.#{facet.downcase}" })

  Plugins.add_search_facets(:reading_room_request, "rrr_time_required_u_ssort")
  Plugins.add_facet_group_i18n("rrr_time_required_u_ssort",
                               proc {|facet| "reading_room_request.time_required_options.#{facet.downcase}" })

  # Eager load all JSON schemas
  Dir.glob(File.join(File.dirname(__FILE__), "..", "schemas", "*.rb")).each do |schema|
    next if schema.end_with?('_ext.rb')
    JSONModel(File.basename(schema, ".rb").intern)
  end

  # register models for qsa_ids
  require_relative '../common/qsa_id_registrations'

  # add new movement context models
  require_relative '../common/movement_contexts'
end
