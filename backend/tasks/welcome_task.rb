class WelcomeTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      json = JSON.parse(task[:blob])

      email_content = EmailTemplates.render('email-welcome', {
        'USER_FIRST_NAME' => json.dig('user', 'first_name'),
        'USER_LAST_NAME' => json.dig('user', 'last_name'),
        'USER_EMAIL' => json.dig('user', 'email'),
        'PUBLIC_BASE_URL' => AppConfig[:qsa_public_baseurl],
        'EMAIL_SIGNATURE' => EmailTemplates.signature,
      })

      begin
        EmailDelivery.new('Thank you for registering with the Queensland State Archives',
                          email_content,
                          [json.fetch('user').fetch('email')])  # to
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

