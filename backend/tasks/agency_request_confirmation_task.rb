class AgencyRequestConfirmationTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      EmailDelivery.new('Confirmation closed record request sent',
                        json,
                        'agency_request_confirmation.txt.erb',
                        [json.fetch('user'.fetch('email'))],
                        [AppConfig[:email_qsa_requests_email]])
                   .send!

      results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
    end

    results
  end

end

