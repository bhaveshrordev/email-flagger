
# Email CSV Flagger

A simple Ruby on Rails application that allows uploading CSV or text files, parses each row to detect valid email addresses, adds a `flag` column (`true` if any valid email exists in the row, `false` otherwise), and allows downloading the processed CSV file.

This version uses an **in-memory JobStore** for tracking file uploads and stores processed files on the file system.  

---

## Features

- Upload CSV / text files via API
- Parse each row and add `flag` column for valid email detection
- Download processed CSV using a unique UUID
- Job status tracking (`pending`, `processing`, `completed`, `failed`)
- Simple in-memory storage for demonstration purposes
- Ready for RSpec tests  

---

## Tech Stack

- **Ruby on Rails 7**
- **PostgreSQL** (optional, currently JobStore is in-memory)
- **RSpec** for testing
- **File system storage** for processed CSVs
- **Linux / Unix environment**  

---

## Installation

1. Clone the repository:

```bash
git clone https://github.com/<your-username>/email-flagger.git
cd email-flagger
```

2. Install dependencies:

```bash
bundle install
```

3. Create database (optional if you want to enable DB later):

```bash
rails db:create
rails db:migrate
```

4. Start the Rails server:

```bash
rails server
```

---

## API Endpoints

### 1️⃣ Upload CSV

```
POST /api/upload
```

**Form Data:**

- `file` — CSV or text file to upload

**Response:**

```json
{
  "id": "a225eb00-0907-4273-92ca-5faadeefae5f"
}
```

- `id` is a unique UUID to download the processed file.

**Example using curl:**

```bash
curl -F "file=@/path/to/sample.csv" http://localhost:3000/api/upload
```

---

### 2️⃣ Download Processed CSV

```
GET /api/download/:id
```

- Replace `:id` with the UUID returned from upload.

**Responses:**

| Status | Meaning |
|--------|---------|
| 200    | File ready, returns CSV download |
| 423    | File still processing |
| 400    | Invalid UUID |

**Example using curl:**

```bash
curl -O -J http://localhost:3000/api/download/a225eb00-0907-4273-92ca-5faadeefae5f
```

> This will save the processed CSV to your current directory.

---

## CSV Processing

- Adds a `flag` column at the **end of each row** (ignoring header).  
- `true` → row contains at least one valid email address  
- `false` → no email detected  
- Uses Ruby’s built-in regex (`URI::MailTo::EMAIL_REGEXP`) for email validation  

---

## Testing

The app uses **RSpec** for request specs:

```bash
bundle exec rspec
```

> Ensure that you have some sample CSV files in `spec/fixtures/files/` if using fixtures.

---

## Directory Structure

```
app/
 ├── controllers/api/uploads_controller.rb
 ├── services/
 │   ├── job_store.rb
 │   └── upload_processor.rb
spec/
 └── requests/api/uploads_spec.rb
storage/
 └── processed CSV files
```

---

## Notes

- **In-memory JobStore**: All job data will be lost on server restart.
- **File system storage**: Processed CSVs are saved in `storage/` folder.
- **Future improvements**:
  - Use ActiveRecord (`FileUpload` model) for persistent job tracking
  - Add background job processing for large files
  - Add authentication & authorization
  - Dockerize for deployment

---

## Author

**Bhavesh Saluja** – Ruby on Rails Developer

---

## License

MIT License