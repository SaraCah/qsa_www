class QuoteRequestTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      p "******************************************************************"
      p json
      p "******************************************************************"

      results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
    end

    results
  end

end

