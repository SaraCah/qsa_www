class AgencyRequestTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      email_content = EmailTemplates.render('email-agency-request', {
        'REQUESTED_ITEMS' => EmailTemplates.render_partial('agency_request_requested_items', json),
        'USER_FIRST_NAME' => json.dig('user', 'first_name'),
        'USER_LAST_NAME' => json.dig('user', 'last_name'),
        'USER_CONTACT_DETAILS' => EmailTemplates.render_partial('agency_request_user_contact_details', json),
        'REQUEST_PURPOSE' => EmailTemplates.preserve_newlines(json['purpose']),
        'REQUEST_PUBLICATION_DETAILS' => json['permission_to_copy'],
        'EMAIL_SIGNATURE' => EmailTemplates.signature,
      })

      emails = delegate_emails_for_agency(json.fetch('agency').fetch('uri'))

      if emails.empty?
        email_content = "<p><strong>AGENCY DOES NOT HAVE A CURRENT DELEGATE SET</strong> - Please forward this message to the appropriate agency contact at #{json.fetch('agency').fetch('display_string')}</p>#{email_content}"
      end

      begin
        EmailDelivery.new('Closed record request - Queensland State Archives User',
                          email_content,
                          json['agency_has_delegate'] ? emails : [AppConfig[:email_qsa_requests_email]],  # to
                          [],  # cc
                          [AppConfig[:email_qsa_requests_email]])  # reply-to
                      .send!

        results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
      rescue
        Log.error($!)
        results << DeferredTaskRunner::TaskResult.new(task[:id], :failed)
      end
    end

    results
  end

  def self.delegate_emails_for_agency(uri)
    agent_id = JSONModel.parse_reference(uri)[:id]
    agent_json = AgentCorporateEntity.to_jsonmodel(agent_id)

    agent_json.delegates.map do |delegate|
      delegate.fetch('email')
    end
  end

end

