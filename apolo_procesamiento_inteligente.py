import logging
import random
import time
from datetime import datetime
from flask import jsonify, request
import functions_framework

# Configuración de logging
logging.basicConfig(level=logging.INFO, force=True)

# Simulador de clasificación
def simulate_classification(file_name):
    categories = ["EstadoDeResultados", "BalanceGeneral", "RegistrosPatronales"]
    category = random.choice(categories)
    confidence = round(random.uniform(0.8, 0.99), 2)
    return {"document_type": category, "confidence": confidence}

# Simulador de extracción
def simulate_extraction(file_name, category):
    # Campos ficticios según categoría
    if category == "RegistrosPatronales":
        fields = {
            "Empresa": "Empresa XYZ",
            "RFC": "XYZ123456789",
            "Total_a_Pagar_Suma": round(random.uniform(1000, 5000), 2),
            "Fecha_Limite": "2025-12-31"
        }
    else:
        fields = {
            "Ingresos": round(random.uniform(10000, 50000), 2),
            "Egresos": round(random.uniform(5000, 20000), 2),
            "Fecha": "2025-12-01"
        }
    # Simular metadatos de posición
    metadata = {
        "page_refs": [{"page": 1, "bbox": {"x1": 100, "y1": 200, "x2": 300, "y2": 220}}],
        "processor_version": "sim-v1",
        "decision_path": "SIMULATED"
    }
    return {"fields": fields, "metadata": metadata}

# ─── Cloud Function entry ─────────────────────────────────────────────
@functions_framework.http
def document_processor(request):
    if request.method != "POST":
        return jsonify({"error": "Method not allowed"}), 405

    data = request.get_json(silent=True) or {}
    logging.info("Incoming event: %s", data)

    preavaluo_id = data.get("preavaluo_id", "SIM-000")
    files = data.get("files", [])

    if not files:
        return jsonify({"error": "No files provided"}), 400

    results = []
    total_files = len(files)

    for idx, f in enumerate(files, start=1):
        file_name = f.get("name", f"file-{idx}.pdf")

        # Simular clasificación
        classification = simulate_classification(file_name)

        # Simular extracción
        extraction = simulate_extraction(file_name, classification["document_type"])

        # Construir resultado
        doc_result = {
            "file_name": file_name,
            "classification": classification,
            "extraction": extraction,
            "processed_at": datetime.utcnow().isoformat()
        }
        results.append(doc_result)

        # Progreso en consola
        progress_pct = round((idx / total_files) * 100, 2)
        logging.info("Processed %s (%d/%d) -> %s%% complete",
                     file_name, idx, total_files, progress_pct)

        # Simular tiempo de procesamiento
        time.sleep(0.5)

    # Respuesta final
    response = {
        "status": "processed",
        "preavaluo_id": preavaluo_id,
        "document_count": total_files,
        "results": results
    }
    return jsonify(response), 200