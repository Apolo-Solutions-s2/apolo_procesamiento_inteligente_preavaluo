# Installation and Usage Guide

## Prerequisites

To generate diagram images, you have two options:

### Option 1: Install Mermaid CLI (Requires Node.js)

1. **Install Node.js**
   - Download from: https://nodejs.org/
   - Choose the LTS version
   - Run the installer and follow the prompts
   - Restart PowerShell after installation

2. **Install Mermaid CLI**
   ```powershell
   npm install -g @mermaid-js/mermaid-cli
   ```

3. **Generate Diagrams**
   ```powershell
   cd diagrams
   mmdc -i firestore-schema.mmd -o firestore-schema.png
   mmdc -i architecture-dataflow.mmd -o architecture-dataflow.png
   mmdc -i sequence-diagram.mmd -o sequence-diagram.png
   ```

### Option 2: Use VS Code Extension (No Node.js Required)

1. **Install Mermaid Preview Extension**
   - Press `Ctrl+Shift+X` to open Extensions
   - Search for "Mermaid Preview" or "Markdown Preview Mermaid Support"
   - Install "Mermaid Preview" by Matt Bierner

2. **View Diagrams**
   - Open any `.mmd` file
   - Press `Ctrl+Shift+V` or right-click and select "Open Preview"

### Option 4: Use Python Script (No Node.js Required)

1. **Ensure Python is installed** (comes with most systems)
2. **Run the generation script**
   ```powershell
   cd diagrams
   python generate_diagrams.py
   ```
   This will generate PNG images for all `.mmd` files using online APIs.

## Quick Start (No Installation)

For immediate viewing without any installation:
1. Open the `.mmd` files in this folder
2. Copy the content
3. Go to https://mermaid.live/
4. Paste and view the diagram
5. Click "Actions" → "PNG" or "SVG" to download

## Current Status

✅ Created diagrams folder at: `c:\Users\LD_51\Desktop\job\ingestaMS\diagrams`
✅ Created 3 Mermaid diagram files:
   - firestore-schema.mmd
   - architecture-dataflow.mmd
   - sequence-diagram.mmd
⚠️ Node.js not installed - required for Mermaid CLI
✓ VS Code extension is the easiest option for Windows
