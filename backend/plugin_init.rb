PublicDB.connect

require_relative 'index_feed/public_indexer_feed_profile'

IndexFeedThread.new("plugin_qsa_public", PublicIndexerFeedProfile.new).start
