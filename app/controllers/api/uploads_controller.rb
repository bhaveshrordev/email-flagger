# app/controllers/api/uploads_controller.rb
class Api::UploadsController < ApplicationController
  # API-only endpoints; skip CSRF for simplicity (if you use API mode, it's already handled)
  protect_from_forgery with: :null_session

  # POST /api/upload
  # param: file (multipart form)
  def create
    uploaded = params[:file]
    unless uploaded.present? && uploaded.respond_to?(:original_filename)
      render json: { error: 'No file uploaded. Please send multipart form with key `file`' }, status: :bad_request
      return
    end

    # accept text/csv or text/plain; allow .csv extension too
    filename = uploaded.original_filename
    content_type = uploaded.content_type.to_s

    allowed = [
      'text/csv', 'text/plain',
      'application/vnd.ms-excel', # sometimes CSVs are this
      'application/csv', 'text/comma-separated-values'
    ]

    unless allowed.include?(content_type) || filename.match?(/\.csv\z/i) || filename.match?(/\.txt\z/i)
      render json: { error: 'Only CSV or text files are allowed' }, status: :bad_request
      return
    end

    # Create job and save a temporary copy of uploaded file
    job = JobStore.create(original_filename: filename)

    tmp_dir = Rails.root.join('tmp', 'uploads')
    FileUtils.mkdir_p(tmp_dir)
    tmp_path = tmp_dir.join("#{job[:id]}_#{sanitize_filename(filename)}")
    # Save uploaded IO to temp_path
    File.open(tmp_path, 'wb') do |f|
      IO.copy_stream(uploaded.tempfile || uploaded, f)
    end

    # Update job to pending -> we'll set to processing in job
    JobStore.update(job[:id], status: 'pending')

    # Enqueue processing job
    ProcessCsvJob.perform_later(job[:id], tmp_path.to_s)

    render json: { id: job[:id] }, status: :ok
  rescue => e
    Rails.logger.error("UploadsController#create error: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end

  # GET /api/download/:id
  def download
    id = params[:id].to_s
    job = JobStore.get(id)
    unless job
      render json: { error: 'Invalid id' }, status: :bad_request
      return
    end

    case job[:status]
    when 'pending', 'processing'
      render json: { error: 'Job is still in progress' }, status: 423 # 423 Locked
    when 'failed'
      render json: { error: "Job failed: #{job[:error] || 'unknown error'}" }, status: :internal_server_error
    when 'completed'
      file_path = job[:stored_path]
      unless file_path && File.exist?(file_path)
        render json: { error: 'Processed file missing' }, status: :internal_server_error
        return
      end

      send_file file_path,
                filename: "processed_#{job[:original_filename]}",
                type: 'text/csv',
                disposition: 'attachment'
    else
      render json: { error: 'Unknown job status' }, status: :internal_server_error
    end
  end

  private

  # basic sanitize
  def sanitize_filename(name)
    name.to_s.gsub(/[^0-9A-Za-z.\-]/, '_')
  end
end
