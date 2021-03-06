PublicDB.connect

require_relative 'index_feed/public_indexer_feed_profile'

ArchivesSpaceService.plugins_loaded_hook do
  if AppConfig.has_key?(:qsa_public_index_feed_enabled) && AppConfig[:qsa_public_index_feed_enabled] == false
    Log.info("QSA Public indexer thread will not be started as AppConfig[:qsa_public_index_feed_enabled] is false")
  else
    Log.info("Starting QSA Public indexer...")
    IndexFeedThread.new("plugin_qsa_public", PublicIndexerFeedProfile.new).start
  end
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
require_relative 'tasks/email_delivery'
require_relative 'tasks/set_price_request_task'
require_relative 'tasks/email_template'

Permission.define('manage_reading_room_requests',
                  'The ability to process reading room requests',
                  :level => "repository")

Permission.define('update_reading_room_requests',
                  'The ability to update reading room requests',
                  :implied_by => "manage_reading_room_requests",
                  :level => "global")

Permission.define('manage_closed_record_approval',
                  'The ability to manage agency approval of closed records',
                  :level => "repository")

Permission.define('approve_closed_records',
                  'The ability to approve or reject closed records',
                  :implied_by => "manage_closed_record_approval",
                  :level => "global")

# register models for history
begin
  [
   ReadingRoomRequest,
   DigitalCopyPricing,
  ].each do |model|
    History.register_model(model)
    History.add_model_map(model, :last_modified_by => :modified_by,
                                 :user_mtime => proc {|obj| obj.modified_time})
  end
rescue NameError
  Log.info("Unable to register qsa_www models for history. Please install the as_history plugin")
end


DeferredTaskRunner.add_handler_for_type('quote_request', QuoteRequestTask)
DeferredTaskRunner.add_handler_for_type('welcome', WelcomeTask)
DeferredTaskRunner.add_handler_for_type('agency_request', AgencyRequestTask)
DeferredTaskRunner.add_handler_for_type('agency_request_confirmation', AgencyRequestConfirmationTask)
DeferredTaskRunner.add_handler_for_type('password_reset', PasswordResetTask)
DeferredTaskRunner.add_handler_for_type('set_price_request', SetPriceRequestTask)

DeferredTaskRunner.start

require 'mail'
if AppConfig[:email_enabled]
  Mail.defaults do
    delivery_method :smtp, AppConfig[:email_smtp_settings]
  end
end
