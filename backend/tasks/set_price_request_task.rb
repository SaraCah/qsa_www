class SetPriceRequestTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      begin
        EmailDelivery.new('Digital copy order - Public User',
                          json,
                          'set_price_request.txt.erb',
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

