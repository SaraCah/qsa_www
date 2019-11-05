class QuoteRequestTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      EmailDelivery.new('Digital copy order - Public User',
                        json,
                        'quote_request.txt.erb',
                        [AppConfig[:email_qsa_requests_email]],
                        [json.fetch('user').fetch('email')])
                    .send!

      results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
    end

    results
  end

end

