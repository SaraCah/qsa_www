class PasswordResetTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      begin
        json = JSON.parse(task[:blob])

        email_content = EmailTemplates.render('email-password-reset', {
          'USER_FIRST_NAME' => json.dig('user', 'first_name'),
          'USER_LAST_NAME' => json.dig('user', 'last_name'),
          'USER_EMAIL' => json.dig('user', 'email'),
          'RESET_URL' => json.dig('reset_url'),
          'EMAIL_SIGNATURE' => EmailTemplates.signature,
        })

        EmailDelivery.new('Reset password - Queensland State Archives',
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

