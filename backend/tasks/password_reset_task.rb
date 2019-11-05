class PasswordResetTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      EmailDelivery.new('QSA Password Reset',
                        json,
                        'password_reset.txt.erb',
                        [json.fetch('user').fetch('email')])
                    .send!

      results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
    end

    results
  end

end

