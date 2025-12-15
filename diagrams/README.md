# Diagrams

This folder contains Mermaid diagrams for the Apolo Ingesta Documentos Preavaluo project.

## Diagrams

### 1. Firestore Schema (firestore-schema.mmd / firestore-schema-simple.png)

This diagram illustrates the complete Firestore database schema used for tracking document processing runs. The schema is organized into two main collections: `runs` (parent collection) and `documents` (subcollection). The `runs` collection stores metadata about each processing batch, including the preavaluo ID, source bucket information, folder prefix, processing status, and counters for total, processed, and failed documents. Each run contains a subcollection of `documents` that tracks individual file processing. Each document record includes identifiers (docId, runId, folioId, fileId), the GCS URI, processing status and timestamps, plus three nested objects: `classification` (containing the detected document type, confidence score, and classifier version), `extraction` (with structured fields like organization name, reporting period, currency, and line items, plus metadata about processing version and table references), and an optional `error` object for failure cases. This hierarchical structure enables efficient tracking and querying of both batch-level and document-level processing states.

### 2. Architecture Data Flow (architecture-dataflow.mmd / architecture-dataflow.png)

This diagram depicts the high-level architecture and data flow between the major Google Cloud Platform components in the document processing pipeline. The flow begins when Cloud Workflows invokes the Cloud Run Job with parameters (runId and folderPrefix). The Cloud Run Job orchestrates the entire process: it lists and loads PDF files from Cloud Storage, sends them to Document AI's Classifier processor to determine document types, then routes them to the appropriate Document AI Extractor processor to extract structured financial data. Throughout processing, the job writes metadata to Firestore—both at the run level (`runs/{runId}`) to track overall progress and at the document level (`runs/{runId}/documents/{docId}`) to store individual results. If processing failures exceed a defined threshold, the job publishes messages to a Pub/Sub Dead Letter Queue (DLQ) for error handling and alerting. This architecture ensures scalable, reliable document processing with comprehensive tracking and error recovery mechanisms.

### 3. End-to-End Sequence (sequence-diagram.mmd / sequence-diagram.png)

This sequence diagram provides a detailed step-by-step view of the document processing workflow from initiation to completion. The process starts when Cloud Workflow invokes the Cloud Run Job with a runId and folderPrefix. The job immediately creates a run record in Firestore with status "processing". It then lists all PDF files in the specified Cloud Storage folder and begins iterating through each file. For each document, the job creates a document record in Firestore (status "processing"), downloads the PDF from Cloud Storage, sends it to the Document AI Classifier to identify the document type, and then sends it to the Document AI Extractor to extract structured fields (organization name, financial statement data, line items, etc.). After processing each document, the job updates the document record in Firestore with the classification and extraction results (status "completed"), and increments the processing counters in the parent run record. Once all files are processed, the job updates the run status to "completed" and returns a processing summary to the Cloud Workflow. This sequence ensures atomic tracking of each processing step with full visibility into the pipeline's progress.

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
