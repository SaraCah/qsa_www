class QuoteRequestTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      p "******************************************************************"
      p self
      p json
      p EmailRenderer.new(json, 'quote_request.txt.erb').render
      p "******************************************************************"

      results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
    end

    results
  end

end

