PublicDB.connect

require_relative 'index_feed/public_indexer_feed_profile'

ArchivesSpaceService.plugins_loaded_hook do
  IndexFeedThread.new("plugin_qsa_public", PublicIndexerFeedProfile.new).start
end

# register models for qsa_ids
require_relative '../common/qsa_id_registrations'

# add new movement context models
require_relative '../common/movement_contexts'


require_relative 'tasks/deferred_task_runner'
require_relative 'tasks/agency_request_confirmation_task'
require_relative 'tasks/agency_request_task'
require_relative 'tasks/password_reset_task'
require_relative 'tasks/quote_request_task'
require_relative 'tasks/welcome_task'

DeferredTaskRunner.add_handler_for_type('quote_request', QuoteRequestTask)
DeferredTaskRunner.add_handler_for_type('welcome', WelcomeTask)
DeferredTaskRunner.add_handler_for_type('agency_request', AgencyRequestTask)
DeferredTaskRunner.add_handler_for_type('agency_request_confirmation', AgencyRequestConfirmationTask)
DeferredTaskRunner.add_handler_for_type('password_reset', PasswordResetTask)

DeferredTaskRunner.start