class PublicDB

  def self.pool
    raise "Not connected" unless @pool

    @pool.pool
  end

  def self.connect
    return if @pool

    @pool = DBPool.new.connect

    connected_hooks.each do |hook|
      hook.call
    end

    connected_hooks.clear
  end

  def self.connected_hooks
    @connected_hooks ||= []
    @connected_hooks
  end

  def self.connected_hook(&block)
    if @pool
      block.call
    else
      self.connected_hooks << block
    end
  end

  def self.disconnect
    @pool.disconnect
    @pool = nil
  end


  def self._generate_instance_methods!
    # Any method called on DB is dispatched to our default pool.
    DBPool.instance_methods(false).each do |method|
      if self.singleton_methods(false).include?(method)
        next
      end

      self.define_singleton_method(method) do |*args, &block|
        if block
          @pool.send(method, *args, &block)
        else
          @pool.send(method, *args)
        end
      end
    end
  end

  class DBPool

    attr_reader :pool, :pool_size

    def initialize(pool_size = AppConfig[:qsa_public_db_max_connections], opts = {})
      @pool_size = pool_size
      @opts = opts
    end

    def connect
      if not @pool

        begin
          Log.info("Connecting to database: #{AppConfig[:qsa_public_db_url_redacted]}. Max connections: #{pool_size}")
          pool = Sequel.connect(AppConfig[:qsa_public_db_url],
                                :max_connections => pool_size,
                                :test => true,
                                :loggers => (AppConfig[:qsa_public_db_debug_log] ? [Logger.new($stderr)] : [])
                               )

          @pool = pool
        rescue
          Log.error("DB connection failed: #{$!}")
        end
      end

      self
    end


    def connected?
      not @pool.nil?
    end


    def transaction(*args)
      @pool.transaction(*args) do
        yield
      end
    end


    def after_commit(&block)
      if @pool.in_transaction?
        @pool.after_commit do
          block.call
        end
      else
        block.call
      end
    end


    def open(transaction = true, opts = {})
      last_err = false
      retries = opts[:retries] || 10

      retries.times do |attempt|
        begin
          if transaction
            self.transaction(:isolation => opts.fetch(:isolation_level, :repeatable)) do
              return yield @pool
            end

            # Sometimes we'll make it to here.  That means we threw a
            # Sequel::Rollback which has been quietly caught.
            return nil
          else
            begin
              return yield @pool
            rescue Sequel::Rollback
              # If we're not in a transaction we can't roll back, but no need to blow up.
              Log.warn("Sequel::Rollback caught but we're not inside of a transaction")
              return nil
            end
          end


        rescue Sequel::DatabaseDisconnectError => e
          # MySQL might have been restarted.
          last_err = e
          Log.info("Connecting to the database failed.  Retrying...")
          sleep(opts[:db_failed_retry_delay] || 3)


        rescue Sequel::NoExistingObject, Sequel::DatabaseError => e
          if (attempt + 1) < retries && is_retriable_exception(e, opts) && transaction
            Log.info("Retrying transaction after retriable exception (#{e})")
            sleep(opts[:retry_delay] || 1)
          else
            raise e
          end
        end

        if last_err
          Log.error("Failed to connect to the database")
          Log.exception(last_err)

          raise "Failed to connect to the database: #{last_err}"
        end
      end
    end

    def in_transaction?
      @pool.in_transaction?
    end

    def is_retriable_exception(exception, opts = {})
      # Transaction was rolled back, but we can retry
      (exception.instance_of?(RetryTransaction) ||
       (opts[:retry_on_optimistic_locking_fail] &&
        exception.instance_of?(Sequel::Plugins::OptimisticLocking::Error)) ||
       (exception.wrapped_exception && ( exception.wrapped_exception.cause or exception.wrapped_exception).getSQLState() =~ /^(40|41)/) )
    end
  end


  PublicDB._generate_instance_methods!
end
