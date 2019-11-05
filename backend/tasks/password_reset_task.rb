class PasswordResetTask

  def self.run_tasks(tasks)
    results = []

    tasks.each do |task|
      json = JSON.parse(task[:blob])

      p "******************************************************************"
      p self
      p json
      p EmailRenderer.new(json, 'password_reset.txt.erb').render
      p "******************************************************************"

      results << DeferredTaskRunner::TaskResult.new(task[:id], :success)
    end

    results
  end

end

