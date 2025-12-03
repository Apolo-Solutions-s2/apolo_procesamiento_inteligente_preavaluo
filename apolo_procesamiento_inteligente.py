import os
import logging
import random
import time
from datetime import datetime

from flask import jsonify
import functions_framework
from google.cloud import storage

# Logging
logging.basicConfig(level=logging.INFO, force=True)

# ─────────────────────────────────────────────────────────────
# Simuladores
# ─────────────────────────────────────────────────────────────
def simulate_classification(file_name: str) -> dict:
    categories = ["EstadoDeResultados", "BalanceGeneral", "RegistrosPatronales"]
    return {
        "document_type": random.choice(categories),
        "confidence": round(random.uniform(0.8, 0.99), 2),
    }


def simulate_extraction(file_name: str, category: str) -> dict:
    if category == "RegistrosPatronales":
        fields = {
            "Empresa": "Empresa XYZ",
            "RFC": "XYZ123456789",
            "Total_a_Pagar_Suma": round(random.uniform(1000, 5000), 2),
            "Fecha_Limite": "2025-12-31",
        }
    else:
        fields = {
            "Ingresos": round(random.uniform(10000, 50000), 2),
            "Egresos": round(random.uniform(5000, 20000), 2),
            "Fecha": "2025-12-01",
        }

    metadata = {
        "page_refs": [{"page": 1, "bbox": {"x1": 100, "y1": 200, "x2": 300, "y2": 220}}],
        "processor_version": "sim-v1",
        "decision_path": "SIMULATED",
    }
    return {"fields": fields, "metadata": metadata}


# ─────────────────────────────────────────────────────────────
# Helpers GCS
# ─────────────────────────────────────────────────────────────
def _normalize_prefix(prefix: str) -> str:
    prefix = (prefix or "").strip()
    if prefix and not prefix.endswith("/"):
        prefix += "/"
    return prefix


def _list_objects(bucket_name: str, prefix: str, allowed_exts: set[str], max_items: int) -> list[str]:
    client = storage.Client()
    bucket = client.bucket(bucket_name)

    names: list[str] = []
    # list_blobs maneja paginación internamente
    for blob in client.list_blobs(bucket, prefix=prefix):
        name = blob.name or ""
        if not name:
            continue

        # Si es "carpeta placeholder" (termina en /) lo ignoramos
        if name.endswith("/"):
            continue

        # Filtrado por extensión
        lower = name.lower()
        if allowed_exts and not any(lower.endswith(ext) for ext in allowed_exts):
            continue

        names.append(name)
        if len(names) >= max_items:
            break

    return names


# ─────────────────────────────────────────────────────────────
# Entry
# ─────────────────────────────────────────────────────────────
@functions_framework.http
def document_processor(request):
    if request.method != "POST":
        return jsonify({"error": "Method not allowed"}), 405

    data = request.get_json(silent=True) or {}
    folder_prefix = _normalize_prefix(data.get("folder_prefix", ""))

    # Bucket por env var (recomendado) o default fijo
    bucket_name = os.environ.get("BUCKET_NAME", "preavaluos-pdf")

    # Preavaluo: si no viene explícito, lo inferimos del primer segmento del prefix
    preavaluo_id = data.get("preavaluo_id") or (folder_prefix.split("/")[0] if folder_prefix else "SIM-000")

    # Extensiones permitidas (opcional en request)
    # Ej: {"extensions": [".pdf", ".xml"]}
    extensions = data.get("extensions") or [".pdf"]
    allowed_exts = {str(x).lower().strip() for x in extensions if str(x).strip()}
    max_items = int(data.get("max_items") or 500)

    if not folder_prefix:
        return jsonify({"error": "folder_prefix is required"}), 400

    logging.info("Incoming event: %s", data)
    logging.info("Bucket=%s Prefix=%s Preavaluo=%s", bucket_name, folder_prefix, preavaluo_id)

    # 1) Listar objetos en el bucket bajo el prefix
    try:
        object_names = _list_objects(bucket_name, folder_prefix, allowed_exts, max_items)
    except Exception as e:
        logging.exception("GCS list failed")
        return jsonify({"error": "Failed to list objects", "details": str(e)}), 500

    if not object_names:
        return jsonify({
            "status": "no_files",
            "preavaluo_id": preavaluo_id,
            "bucket": bucket_name,
            "folder_prefix": folder_prefix,
            "document_count": 0,
            "results": []
        }), 200

    # 2) Simulación por archivo
    results = []
    total_files = len(object_names)

    logging.info("Found %d objects to process.", total_files)

    for idx, file_name in enumerate(object_names, start=1):
        classification = simulate_classification(file_name)
        extraction = simulate_extraction(file_name, classification["document_type"])

        results.append({
            "file_name": file_name,
            "gcs_uri": f"gs://{bucket_name}/{file_name}",
            "classification": classification,
            "extraction": extraction,
            "processed_at": datetime.utcnow().isoformat(),
        })

        progress_pct = round((idx / total_files) * 100.0, 2)
        logging.info("Processed %s (%d/%d) -> %s%%", file_name, idx, total_files, progress_pct)

        time.sleep(0.2)  # simulación

    return jsonify({
        "status": "processed",
        "preavaluo_id": preavaluo_id,
        "bucket": bucket_name,
        "folder_prefix": folder_prefix,
        "document_count": total_files,
        "results": results,
    }), 200
