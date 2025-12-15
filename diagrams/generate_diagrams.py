"""
Generate diagram images from Mermaid files using Python.
This script uses the mermaid.ink API to generate PNG images without requiring Node.js.
"""

import urllib.request
import urllib.parse
import base64
import os
from pathlib import Path


def generate_diagram(mermaid_file: str, output_file: str):
    """
    Generate a PNG diagram from a Mermaid file using mermaid.ink API.
    
    Args:
        mermaid_file: Path to the .mmd file
        output_file: Path to save the output PNG file
    """
    print(f"Processing {mermaid_file}...")
    
    # Read the mermaid content
    with open(mermaid_file, 'r', encoding='utf-8') as f:
        mermaid_code = f.read()
    
    # Try different API endpoints
    apis = [
        ("mermaid.ink", lambda code: f"https://mermaid.ink/img/{base64.b64encode(code.encode('utf-8')).decode('utf-8')}"),
        ("kroki.io", lambda code: f"https://kroki.io/mermaid/png/{base64.urlsafe_b64encode(code.encode('utf-8')).decode('utf-8')}")
    ]
    
    for api_name, url_builder in apis:
        try:
            url = url_builder(mermaid_code)
            print(f"  Trying {api_name} API...")
            urllib.request.urlretrieve(url, output_file)
            print(f"  ✓ Saved to {output_file}")
            return True
        except Exception as e:
            print(f"  ✗ {api_name} failed: {e}")
            continue
    
    print(f"  ✗ All APIs failed for this diagram")
    return False


def main():
    """Generate all diagrams in the current directory."""
    script_dir = Path(__file__).parent
    
    # List of mermaid files to process
    mermaid_files = [
        ('firestore-schema.mmd', 'firestore-schema.png'),
        ('firestore-schema-simple.mmd', 'firestore-schema-simple.png'),
        ('architecture-dataflow.mmd', 'architecture-dataflow.png'),
        ('sequence-diagram.mmd', 'sequence-diagram.png'),
    ]
    
    print("=" * 60)
    print("Mermaid Diagram Generator")
    print("=" * 60)
    print()
    
    success_count = 0
    for mmd_file, png_file in mermaid_files:
        mmd_path = script_dir / mmd_file
        png_path = script_dir / png_file
        
        if not mmd_path.exists():
            print(f"⚠ Skipping {mmd_file} (file not found)")
            continue
        
        if generate_diagram(str(mmd_path), str(png_path)):
            success_count += 1
        print()
    
    print("=" * 60)
    print(f"Generated {success_count}/{len(mermaid_files)} diagrams successfully!")
    print("=" * 60)


if __name__ == '__main__':
    main()
