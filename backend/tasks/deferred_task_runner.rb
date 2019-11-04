class DeferredTaskRunner

  PENDING_STATUS = 'pending'
  RUNNING_STATUS = 'running'

  # FIXME: AppConfig
  MAX_TASK_AGE_MS = 600_000

  TaskResult = Struct.new(:id, :status) do
    def success?
      status == :success
    end
  end

  def self.start
    self.new.start
  end

  def self.add_handler_for_type(type, callback)
    @handlers ||= {}
    @handlers[type] = callback
  end

  def self.handler_for_type(type)
    (@handlers || {}).fetch(type) do
      raise "No handler for #{type}"
    end
  end

  def start
    Thread.new do
      loop do
        begin
          run_round
        rescue
          $LOG.error("Deferred task runner caught exception: #{$!}")
          $LOG.error($@.join("\n"))
        end

        sleep 5                 # FIXME: AppConfig
      end
    end
  end

  def run_round
    PublicDB.open(transaction: false) do |publicdb|
      tasks_by_type = {}

      # Anything that looks to have been abandoned gets picked up again
      # eventually.
      abandoned_tasks = publicdb[:deferred_task_running].where { last_checked_time < ((Time.now.to_i * 1000) - MAX_TASK_AGE_MS) }.select(:task_id)

      publicdb[:deferred_task].filter(:id => abandoned_tasks).update(:status => PENDING_STATUS)
      publicdb[:deferred_task_running].filter(:task_id => abandoned_tasks.map{|row| row[:task_id]}).delete

      publicdb[:deferred_task].filter(:status => PENDING_STATUS).each do |task|
        tasks_by_type[task[:type]] ||= []
        tasks_by_type[task[:type]] << task
      end

      all_tasks = tasks_by_type.values.flatten
      publicdb[:deferred_task_running].multi_insert(
        all_tasks.map {|task|
          {
            task_id: task[:id],
            last_checked_time: java.lang.System.currentTimeMillis
          }
        })

      publicdb[:deferred_task].filter(:id => all_tasks.map {|task| task[:id]}).update(:status => RUNNING_STATUS)

      watchdog_running = java.util.concurrent.atomic.AtomicBoolean.new(true)

      watchdog_thread = Thread.new do
        PublicDB.open(transaction: false) do |publicdb|
          while watchdog_running.get
            now = java.lang.System.currentTimeMillis

            publicdb[:deferred_task_running].filter(:task_id => all_tasks.map {|task| task[:id]}).update(:last_checked_time => now)
            sleep 5
          end
        end
      end

      tasks_by_type.each do |type, tasks|
        begin
          task_results = DeferredTaskRunner.handler_for_type(type).run_tasks(tasks)

          # Remove tasks that succeeded
          publicdb[:deferred_task].filter(:id => task_results.select(&:success?).map(&:id)).delete

          # Decrement retry count for those who failed
          publicdb[:deferred_task].filter(:id => task_results.map(&:id)).update(:retries_remaining => :retries_remaining - Sequel.expr(1))

          # End of the line buddy
          publicdb[:deferred_task]
            .filter(:id => task_results.map(&:id))
            .where { retries_remaining <= 0 }
            .each do |task|
            $LOG.error("Task could not be completed: #{task.inspect}")
          end

          publicdb[:deferred_task]
            .filter(:id => task_results.map(&:id))
            .where { retries_remaining <= 0 }
            .delete

          # Decrement retry count for those who failed
          publicdb[:deferred_task].filter(:id => task_results.map(&:id)).update(:status => PENDING_STATUS)
        rescue
          $LOG.error("FATAL ERROR running tasks of type #{type}: #{tasks.inspect}: #{$!}")
          $LOG.error($@.join("\n"))
          publicdb[:deferred_task].filter(:id => tasks.map {|task| task[:id]}).update(:status => 'ABORTED')
        end
      end

      watchdog_running.set(false)
      watchdog_thread.join

      publicdb[:deferred_task_running].filter(:task_id => tasks_by_type.values.flatten.map {|task| task[:id]}).delete
    end
  end

end
