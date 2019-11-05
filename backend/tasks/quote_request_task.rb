class QuoteRequestTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      begin
        EmailDelivery.new('Digital copy order - Public User',
                          json,
                          'quote_request.txt.erb',
                          [AppConfig[:email_qsa_requests_email]],
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

