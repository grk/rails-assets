module Build
  module Locking
    extend self

    # Create an exclusive lock and yield
    def lock(lock_name, options = {})
      mutex = build_mutex(lock_name, options)

      begin
        mutex.lock
        yield
      ensure
        mutex.unlock
      end
    end

    # Create a lock and yield, other threads waiting for the same lock
    # will return when the lock is done without doing any work
    #
    # Only the first thread will get the result of the block returned,
    # threads that just waited for the result get nil
    def lock_once(lock_name, options = {})
      mutex = build_mutex(lock_name, options)

      begin
        if mutex.try_lock # make a nonblocking attempt to lock
          # we're the first process to obtain the lock, perform
          yield
        else
          # Another threat is already synchronizing, let's just lock and
          # wait until it's done
          mutex.lock
          nil
        end
      ensure
        mutex.unlock
      end
    end

    private
    def build_mutex(lock_name, options = {})
      duration = options.fetch(:duration, 240)
      expire = options.fetch(:expire, 260)
      Redis::Mutex.new(lock_name, block: duration, expire: expire)
    end
  end
end
