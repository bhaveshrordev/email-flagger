# config/initializers/storage.rb
storage_dir = Rails.root.join('storage', 'uploads')
FileUtils.mkdir_p(storage_dir) unless Dir.exist?(storage_dir)
