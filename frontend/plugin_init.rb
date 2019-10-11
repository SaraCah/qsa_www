ArchivesSpace::Application.extend_aspace_routes(File.join(File.dirname(__FILE__), "routes.rb"))


Rails.application.config.after_initialize do
  Plugins.add_search_facets(:reading_room_request, "rrr_status_u_ssort")
  Plugins.add_facet_group_i18n("rrr_status_u_ssort",
                               proc {|facet| "reading_room_requests.statuses.#{facet.downcase}" })

  # Eager load all JSON schemas
  Dir.glob(File.join(File.dirname(__FILE__), "..", "schemas", "*.rb")).each do |schema|
    next if schema.end_with?('_ext.rb')
    JSONModel(File.basename(schema, ".rb").intern)
  end
end
