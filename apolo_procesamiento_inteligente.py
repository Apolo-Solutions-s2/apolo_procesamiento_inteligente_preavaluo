import os
import json
import logging
import random
import time
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set, Tuple

from flask import jsonify
import functions_framework
from google.cloud import storage

# ─────────────────────────────────────────────────────────────
# Logging base (stdout/stderr -> Cloud Logging en Run/Functions)
# ─────────────────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO, force=True)


def _utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _normalize_prefix(prefix: str) -> str:
    p = (prefix or "").strip()
    if p and not p.endswith("/"):
        p += "/"
    return p


def _safe_int(value: Any, default: int) -> int:
    try:
        v = int(value)
        return v if v > 0 else default
    except Exception:
        return default


def _log_progress(
    *,
    run_id: str,
    preavaluo_id: str,
    bucket: str,
    folder_prefix: str,
    step: str,
    percent: int,
    extra: Optional[Dict[str, Any]] = None,
) -> None:
    """
    Emite un log en formato JSON (texto) para poder consultarlo y parsearlo desde Cloud Logging.
    Tu jefe puede luego calcular porcentaje leyendo el último evento por run_id.
    """
    payload: Dict[str, Any] = {
        "event_type": "progress",
        "ts_utc": _utc_iso(),
        "run_id": run_id,
        "preavaluo_id": preavaluo_id,
        "bucket": bucket,
        "folder_prefix": folder_prefix,
        "step": step,
        "percent": int(percent),
    }
    if extra:
        payload.update(extra)

    # JSON “estable” para que sea fácil de buscar/parsear.
    logging.info(json.dumps(payload, ensure_ascii=False))


# ─────────────────────────────────────────────────────────────
# Simuladores
# ─────────────────────────────────────────────────────────────
def simulate_classification(file_name: str) -> Dict[str, Any]:
    categories = ["EstadoDeResultados", "BalanceGeneral", "RegistrosPatronales"]
    return {
        "document_type": random.choice(categories),
        "confidence": round(random.uniform(0.8, 0.99), 2),
    }


def simulate_extraction(file_name: str, category: str) -> Dict[str, Any]:
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
# GCS helpers
# ─────────────────────────────────────────────────────────────
def _list_object_names(
    bucket_name: str,
    prefix: str,
    allowed_exts: Set[str],
    max_items: int,
) -> List[str]:
    client = storage.Client()
    names: List[str] = []

    for blob in client.list_blobs(bucket_name, prefix=prefix):
        name = (blob.name or "").strip()
        if not name:
            continue
        if name.endswith("/"):  # “carpeta” placeholder
            continue

        lower = name.lower()
        if allowed_exts and not any(lower.endswith(ext) for ext in allowed_exts):
            continue

        names.append(name)
        if len(names) >= max_items:
            break

    return names


# ─────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────
@functions_framework.http
def document_processor(request):
    if request.method != "POST":
        return jsonify({"error": "Method not allowed"}), 405

    data = request.get_json(silent=True) or {}

    # Inputs
    folder_prefix = _normalize_prefix(data.get("folder_prefix", ""))
    if not folder_prefix:
        return jsonify({"error": "folder_prefix is required"}), 400

    bucket_name = os.environ.get("BUCKET_NAME", "preavaluos-pdf")

    # Correlación (ideal: el workflow te manda workflow_execution_id)
    run_id = (
        str(data.get("workflow_execution_id") or "").strip()
        or str(data.get("run_id") or "").strip()
        or f"run-{int(time.time())}"
    )

    # preavaluo_id: si no viene, lo inferimos del primer segmento del prefix
    preavaluo_id = str(data.get("preavaluo_id") or "").strip()
    if not preavaluo_id:
        preavaluo_id = folder_prefix.split("/")[0] if folder_prefix else "SIM-000"

    # Extensiones a incluir (por default PDFs)
    extensions = data.get("extensions") or [".pdf"]
    allowed_exts = {str(x).lower().strip() for x in extensions if str(x).strip()}

    max_items = _safe_int(data.get("max_items"), default=500)

    _log_progress(
        run_id=run_id,
        preavaluo_id=preavaluo_id,
        bucket=bucket_name,
        folder_prefix=folder_prefix,
        step="START",
        percent=0,
    )

    # 20%: entrando / preparando listado
    _log_progress(
        run_id=run_id,
        preavaluo_id=preavaluo_id,
        bucket=bucket_name,
        folder_prefix=folder_prefix,
        step="LIST_BUCKET_START",
        percent=20,
        extra={"max_items": max_items, "extensions": sorted(list(allowed_exts))},
    )

    try:
        object_names = _list_object_names(bucket_name, folder_prefix, allowed_exts, max_items)
    except Exception as e:
        logging.exception("GCS list failed")
        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="LIST_BUCKET_ERROR",
            percent=20,
            extra={"error": str(e)},
        )
        return jsonify({"error": "Failed to list objects", "details": str(e)}), 500

    total_files = len(object_names)
    _log_progress(
        run_id=run_id,
        preavaluo_id=preavaluo_id,
        bucket=bucket_name,
        folder_prefix=folder_prefix,
        step="LIST_BUCKET_DONE",
        percent=20,
        extra={"total_files": total_files},
    )

    if total_files == 0:
        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="DONE_NO_FILES",
            percent=100,
        )
        return jsonify({
            "status": "no_files",
            "run_id": run_id,
            "preavaluo_id": preavaluo_id,
            "bucket": bucket_name,
            "folder_prefix": folder_prefix,
            "document_count": 0,
            "results": [],
        }), 200

    # 40%: iniciar clasificación
    _log_progress(
        run_id=run_id,
        preavaluo_id=preavaluo_id,
        bucket=bucket_name,
        folder_prefix=folder_prefix,
        step="CLASSIFY_START",
        percent=40,
        extra={"total_files": total_files},
    )

    classifications: Dict[str, Dict[str, Any]] = {}
    for idx, name in enumerate(object_names, start=1):
        classifications[name] = simulate_classification(name)
        # Log opcional por archivo (no cambia el percent “hito”)
        logging.info(json.dumps({
            "event_type": "progress_detail",
            "ts_utc": _utc_iso(),
            "run_id": run_id,
            "step": "CLASSIFY_ITEM",
            "current_file": idx,
            "total_files": total_files,
            "file_name": name,
        }, ensure_ascii=False))
        time.sleep(0.05)

    # 60%: clasificación terminada
    _log_progress(
        run_id=run_id,
        preavaluo_id=preavaluo_id,
        bucket=bucket_name,
        folder_prefix=folder_prefix,
        step="CLASSIFY_DONE",
        percent=60,
        extra={"total_files": total_files},
    )

    # 70%: iniciar extracción
    _log_progress(
        run_id=run_id,
        preavaluo_id=preavaluo_id,
        bucket=bucket_name,
        folder_prefix=folder_prefix,
        step="EXTRACT_START",
        percent=70,
        extra={"total_files": total_files},
    )

    results: List[Dict[str, Any]] = []
    for idx, name in enumerate(object_names, start=1):
        c = classifications[name]
        e = simulate_extraction(name, c["document_type"])
        results.append({
            "file_name": name,
            "gcs_uri": f"gs://{bucket_name}/{name}",
            "classification": c,
            "extraction": e,
            "processed_at": datetime.utcnow().isoformat(),
        })

        logging.info(json.dumps({
            "event_type": "progress_detail",
            "ts_utc": _utc_iso(),
            "run_id": run_id,
            "step": "EXTRACT_ITEM",
            "current_file": idx,
            "total_files": total_files,
            "file_name": name,
        }, ensure_ascii=False))
        time.sleep(0.05)

    # 80%: extracción terminada
    _log_progress(
        run_id=run_id,
        preavaluo_id=preavaluo_id,
        bucket=bucket_name,
        folder_prefix=folder_prefix,
        step="EXTRACT_DONE",
        percent=80,
        extra={"total_files": total_files},
    )

    # (simula “empaquetado/finalización”)
    time.sleep(0.05)

    # 100%: proceso finalizado
    _log_progress(
        run_id=run_id,
        preavaluo_id=preavaluo_id,
        bucket=bucket_name,
        folder_prefix=folder_prefix,
        step="DONE",
        percent=100,
        extra={"document_count": total_files},
    )

    return jsonify({
        "status": "processed",
        "run_id": run_id,
        "preavaluo_id": preavaluo_id,
        "bucket": bucket_name,
        "folder_prefix": folder_prefix,
        "document_count": total_files,
        "results": results,
    }), 200
