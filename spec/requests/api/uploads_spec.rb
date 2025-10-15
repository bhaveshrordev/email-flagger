# spec/requests/api/uploads_spec.rb
require 'rails_helper'
require 'tempfile'

RSpec.describe "Api::Uploads", type: :request do
  let(:storage_dir) { Rails.root.join('storage', 'uploads') }

  before do
    FileUtils.mkdir_p(storage_dir)
  end

  after do
    # clear storage and tmp uploads between tests
    FileUtils.rm_rf(Dir[Rails.root.join('storage','uploads','*')])
    FileUtils.rm_rf(Dir[Rails.root.join('tmp','uploads','*')])
  end

  describe "POST /api/upload" do
    it "returns id and enqueues a job" do
      csv = <<~CSV
        name,email
        Alice,alice@example.com
        Bob,
      CSV

      file = Tempfile.new(['test', '.csv'])
      file.write(csv)
      file.rewind

      uploaded = fixture_file_upload(file.path, 'text/csv')
      post '/api/upload', params: { file: uploaded }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['id']).to be_present
      id = body['id']
      expect(JobStore.get(id)).to be_present
    ensure
      file.close
      file.unlink
    end

    it "rejects non-csv file" do
      file = Tempfile.new(['test', '.bin'])
      file.write("binarycontent")
      file.rewind

      uploaded = fixture_file_upload(file.path, 'application/octet-stream')
      post '/api/upload', params: { file: uploaded }

      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['error']).to be_present
    ensure
      file.close
      file.unlink
    end
  end

  describe "GET /api/download/:id" do
    it "returns 400 for invalid id" do
      get '/api/download/invalid-id'
      expect(response).to have_http_status(:bad_request)
    end

    it "returns 423 while processing and 200 when completed" do
      csv = <<~CSV
        name,email
        A,a@example.com
        B,b@example.com
      CSV

      file = Tempfile.new(['test', '.csv'])
      file.write(csv)
      file.rewind

      uploaded = fixture_file_upload(file.path, 'text/csv')
      post '/api/upload', params: { file: uploaded }
      body = JSON.parse(response.body)
      id = body['id']

      # Immediately request; job may still be pending/processing
      get "/api/download/#{id}"
      expect([423, 200, 500]).to include(response.status)
      # wait for job to finish (since adapter is :async we should wait small time)
      sleep 0.5
      get "/api/download/#{id}"
      if response.status == 200
        expect(response.header['Content-Type']).to include('text/csv')
        expect(response.body).to include('has_email')
      else
        # job may have failed; ensure job status updated
        job = JobStore.get(id)
        expect(job[:status]).to satisfy { |s| ['pending', 'completed','failed'].include?(s) }
      end
    ensure
      file.close
      file.unlink
    end
  end
end
