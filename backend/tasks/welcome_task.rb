class WelcomeTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      begin
        EmailDelivery.new('Thank you for registering with the Queensland State Archives',
                          json,
                          'welcome.txt.erb',
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

