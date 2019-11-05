class AgencyRequestTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      emails = delegate_emails_for_agency(json.fetch('agency').fetch('uri'))
      json['agency_has_delegate'] = !emails.empty?

      EmailDelivery.new('QSA Closed Record Request',
                        json,
                        'agency_request.txt.erb',
                        emails.empty? ? [AppConfig[:email_qsa_requests_email]] : emails,
                        [AppConfig[:email_qsa_requests_email]])
                    .send!

      results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
    end

    results
  end

  def self.delegate_emails_for_agency(uri)
    agent_id = JSONModel.parse_reference(uri)[:id]
    agent_json = AgentCorporateEntity.to_jsonmodel(agent_id)

    emails = agent_json.delegates.map do |delegate|
      delegate.fetch('email')
    end
  end

end

