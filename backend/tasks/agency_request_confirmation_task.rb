class AgencyRequestConfirmationTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      email_content = EmailTemplates.render('email-agency-request-confirmation', {
        'USER_FIRST_NAME' => json.dig('user', 'first_name'),
        'USER_LAST_NAME' => json.dig('user', 'last_name'),
        'AGENCY_DISPLAY_NAME' => json.dig('agency', 'display_string'),
        'REQUESTED_ITEMS' => EmailTemplates.render_partial('agency_request_confirmation_requested_items', json),
        'EMAIL_SIGNATURE' => EmailTemplates.signature,
      })

      begin
        EmailDelivery.new('Confirmation closed record request sent',
                          email_content,
                          [json.fetch('user').fetch('email')],  # to
                          [],  # cc
                          [AppConfig[:email_qsa_requests_email]])  # reply-to
                     .send!

        results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
      rescue
        Log.error("Failure in AgencyRequestConfirmationTask: #{$!}")
        Log.exception($!)
        results << DeferredTaskRunner::TaskResult.new(task[:id], :failed)
      end
    end

    results
  end

end

