class PasswordResetTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      begin
        EmailDelivery.new('Reset password - Queensland State Archives',
                          json,
                          'password_reset.txt.erb',
                          [json.fetch('user').fetch('email')])
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

