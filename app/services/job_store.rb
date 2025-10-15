# app/services/job_store.rb
class JobStore
  # job structure:
  # {
  #   id: "uuid",
  #   status: 'pending'|'processing'|'completed'|'failed',
  #   original_filename: 'orig.csv',
  #   stored_path: '/full/path/to/processed.csv' (present when completed),
  #   error: 'message' (present when failed),
  #   created_at: Time, updated_at: Time
  # }

  @mutex = Mutex.new
  @jobs = {}

  class << self
    def create(attrs = {})
      id = SecureRandom.uuid
      j = {
        id: id,
        status: 'pending',
        original_filename: attrs[:original_filename],
        stored_path: nil,
        error: nil,
        created_at: Time.current,
        updated_at: Time.current
      }
      @mutex.synchronize { @jobs[id] = j }
      j.dup
    end

    def update(id, changes = {})
      @mutex.synchronize do
        job = @jobs[id]
        return nil unless job
        changes.each { |k, v| job[k] = v }
        job[:updated_at] = Time.current
        job.dup
      end
    end

    def get(id)
      @mutex.synchronize { job = @jobs[id] and job.dup }
    end

    def exists?(id)
      @mutex.synchronize { @jobs.key?(id) }
    end

    def all
      @mutex.synchronize { @jobs.values.map(&:dup) }
    end

    def delete(id)
      @mutex.synchronize { @jobs.delete(id) }
    end
  end
end
