# Diagrams

This folder contains Mermaid diagrams for the Apolo Ingesta Documentos Preavaluo project.

# Diagrams

This folder contains Mermaid diagrams for the Apolo Procesamiento Inteligente Preavaluo project.

## Diagrams

### 1. Firestore Schema (firestore-schema.mmd / firestore-schema-simple.mmd)

These diagrams illustrate the complete Firestore database schema used for tracking document processing. The schema is organized hierarchically:

- **folios/{folioId}**: Parent collection storing metadata about each processing batch (folder), including bucket, folder_prefix, status, document counts, and timestamps.
- **folios/{folioId}/documentos/{docId}**: Subcollection tracking individual document processing with GCS URI, generation for idempotencia, classification results, and status.
- **folios/{folioId}/documentos/{docId}/extracciones/{extractionId}**: Subcollection storing structured extraction results with fields like organization name, reporting period, currency, and line items, plus metadata.

This hierarchical structure enables efficient tracking of folder-level and document-level processing states with full idempotencia.

### 2. Architecture Data Flow (architecture-dataflow.mmd)

This diagram depicts the high-level architecture and data flow between Google Cloud Platform components. The flow begins when Eventarc detects the creation of an 'is_ready' sentinel file in Cloud Storage, triggering the Cloud Run service. The service processes PDFs in parallel: lists files from GCS, downloads PDFs, classifies them using Document AI Classifier (us-south1), extracts structured data with Document AI Extractor (us-south1), and persists results to Firestore. Structured logs are sent to Cloud Logging, and persistent failures are published to Pub/Sub DLQ. The architecture ensures scalable, reliable document processing with comprehensive observability.

### 3. End-to-End Sequence (sequence-diagram.mmd)

This sequence diagram provides a detailed step-by-step view of the document processing workflow. The process starts when Eventarc triggers the Cloud Run service upon detecting an 'is_ready' file. The service creates a folio record in Firestore, logs the start, lists PDFs, and processes them in parallel. For each document, it updates status to IN_PROGRESS, downloads the PDF, classifies and extracts data using Document AI, persists results to Firestore, and logs each step with specific event_types. Failed documents are sent to DLQ, and the folio is marked as DONE or DONE_WITH_ERRORS. This sequence ensures atomic tracking with idempotencia and full logging for observability.

## Viewing the Diagrams

### Option 1: VS Code Extension
Install the Mermaid extension in VS Code to preview diagrams directly:
- Open VS Code Extensions (Ctrl+Shift+X)
- Search for "Mermaid Preview" or "Markdown Preview Mermaid Support"
- Install and open any .mmd file to see the preview

### Option 2: Generate PNG/SVG Images
Use the Mermaid CLI to generate image files:

```powershell
# Install Mermaid CLI globally
npm install -g @mermaid-js/mermaid-cli

# Generate PNG images
mmdc -i firestore-schema.mmd -o firestore-schema.png
mmdc -i architecture-dataflow.mmd -o architecture-dataflow.png
mmdc -i sequence-diagram.mmd -o sequence-diagram.png

# Or generate all at once
Get-ChildItem *.mmd | ForEach-Object { mmdc -i $_.Name -o ($_.BaseName + ".png") }
```

### Option 3: Online Viewer
Copy and paste the diagram code into the [Mermaid Live Editor](https://mermaid.live/)

## Requirements

- Node.js and npm (for Mermaid CLI)
- Or use VS Code extensions for live preview
