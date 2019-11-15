class AgencyRequestConfirmationTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      begin
        EmailDelivery.new('Confirmation closed record request sent',
                          json,
                          'agency_request_confirmation.txt.erb',
                          [json.fetch('user').fetch('email')],  # to
                          [],  # cc
                          [AppConfig[:email_qsa_requests_email]])  # reply-to
                     .send!

        results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
      rescue
        Log.error("Failure in AgencyRequestConfirmationTask: #{$!}")
        Log.exception($!)
        results << DeferredTaskRunner::TaskResult.new(task[:id], :failed)
      end
    end

    results
  end

end

