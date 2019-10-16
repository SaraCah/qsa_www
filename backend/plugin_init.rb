PublicDB.connect

require_relative 'index_feed/public_indexer_feed_profile'

ArchivesSpaceService.plugins_loaded_hook do
  IndexFeedThread.new("plugin_qsa_public", PublicIndexerFeedProfile.new).start
end

# register models for qsa_ids
require_relative '../common/qsa_id_registrations'

# add new movement context models
require_relative '../common/movement_contexts'
