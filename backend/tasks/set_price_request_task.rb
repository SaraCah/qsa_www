class SetPriceRequestTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      email_content = EmailTemplates.render('email-set-price-request', {
        'USER_FIRST_NAME' => json.dig('user', 'first_name'),
        'USER_LAST_NAME' => json.dig('user', 'last_name'),
        'USER_EMAIL' => json.dig('user', 'email'),
        'ORDER_SUMMARY' => EmailTemplates.render_partial('set_price_request_order_summary', json),
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

