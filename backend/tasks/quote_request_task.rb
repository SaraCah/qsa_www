class QuoteRequestTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      email_content = EmailTemplates.render('email-quote-request', {
        'USER_FIRST_NAME' => json.dig('user', 'first_name'),
        'USER_LAST_NAME' => json.dig('user', 'last_name'),
        'USER_CONTACT_DETAILS' => EmailTemplates.render_partial('quote_request_user_contact_details', json),
        'REQUESTED_ITEMS' => EmailTemplates.render_partial('quote_request_requested_items', json),
        'EMAIL_SIGNATURE' => EmailTemplates.signature,
      })

      begin
        EmailDelivery.new('Digital copy order - Public User',
                          email_content,
                          [AppConfig[:email_qsa_requests_email]], # to
                          [json.fetch('user').fetch('email')],    # cc
                          [json.fetch('user').fetch('email')])    # reply-to
                      .send!

        results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
      rescue
        Log.error($!)
        results << DeferredTaskRunner::TaskResult.new(task[:id], :failed)
      end
    end

    results
  end

end

