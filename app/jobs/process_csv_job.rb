# app/jobs/process_csv_job.rb
require 'csv'

class ProcessCsvJob < ApplicationJob
  queue_as :default

  # email validation: simple regex (or use URI::MailTo::EMAIL_REGEXP)
  EMAIL_REGEX = URI::MailTo::EMAIL_REGEXP

  def perform(job_id, temp_input_path)
    job = JobStore.get(job_id)
    unless job
      Rails.logger.error("ProcessCsvJob: no job for id=#{job_id}")
      return
    end

    JobStore.update(job_id, status: 'processing')

    storage_dir = Rails.root.join('storage', 'uploads')
    FileUtils.mkdir_p(storage_dir) unless Dir.exist?(storage_dir)
    output_path = storage_dir.join("#{job_id}.csv").to_s

    begin
      # Read entire CSV (we expect smallish files - ok for demo)
      # We'll treat the first row as header (ignoring header for flagging)
      rows = CSV.read(temp_input_path, headers: false, encoding: 'bom|utf-8')

      if rows.nil? || rows.empty?
        # nothing to process
        CSV.open(output_path, 'w', write_headers: false) {}
        JobStore.update(job_id, status: 'completed', stored_path: output_path)
        return
      end

      # assume first row is header; append header column name
      header = rows.first
      # Append column name "has_email" to header
      CSV.open(output_path, 'w', write_headers: false, encoding: 'utf-8') do |csv_out|
        csv_out << header + ['has_email']

        # Process subsequent rows
        rows.drop(1).each do |row|
          # row is an Array (CSV::Row with headers:false returns Array)
          # If row is all blank (empty row), write as-is (no flag)
          if row.all? { |f| f.nil? || f.to_s.strip.empty? }
            csv_out << row
            next
          end

          # if any field matches email regex
          has_email = row.any? do |field|
            next false if field.nil?
            field.to_s.match?(EMAIL_REGEX)
          end

          csv_out << (row + [has_email ? 'true' : 'false'])
        end
      end

      JobStore.update(job_id, status: 'completed', stored_path: output_path)
    rescue => e
      Rails.logger.error("ProcessCsvJob failed for #{job_id}: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
      JobStore.update(job_id, status: 'failed', error: e.message)
    ensure
      # cleanup temp input file
      FileUtils.rm_f(temp_input_path) if temp_input_path && File.exist?(temp_input_path)
    end
  end
end
