PublicDB.connect

require_relative 'index_feed/public_indexer_feed_profile'

ArchivesSpaceService.plugins_loaded_hook do
  IndexFeedThread.new("plugin_qsa_public", PublicIndexerFeedProfile.new).start
end

# add new movement context models
require_relative '../common/movement_contexts'
