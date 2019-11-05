class AgencyRequestConfirmationTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      p "******************************************************************"
      p self
      p json
      p EmailRenderer.new(json, 'agency_request_confirmation.txt.erb').render
      p "******************************************************************"

      results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
    end

    results
  end

end

