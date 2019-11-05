class WelcomeTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      EmailDelivery.new('Welcome to QSA',
                        json,
                        'welcome.txt.erb',
                        [json.fetch('user').fetch('email')])
                    .send!

      results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
    end

    results
  end

end

