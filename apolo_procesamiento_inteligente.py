import os
import json
import uuid
import time
import random
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set, Tuple

from flask import jsonify
import functions_framework
from google.cloud import storage

logging.basicConfig(level=logging.INFO, force=True)


# ─────────────────────────────────────────────────────────────
# Error model (para devolver 500 con código específico)
# ─────────────────────────────────────────────────────────────
class AppError(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        *,
        stage: str,
        details: Optional[Dict[str, Any]] = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.stage = stage
        self.details = details or {}


# ─────────────────────────────────────────────────────────────
# Utils
# ─────────────────────────────────────────────────────────────
def _utc_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _normalize_prefix(prefix: Any) -> str:
    if prefix is None:
        return ""
    if not isinstance(prefix, str):
        return ""
    p = prefix.strip()
    if p and not p.endswith("/"):
        p += "/"
    return p


def _safe_int(value: Any, default: int) -> int:
    try:
        v = int(value)
        return v if v > 0 else default
    except Exception:
        return default


def _make_run_id(data: Dict[str, Any]) -> str:
    # Preferimos correlacionar con workflow_execution_id si existe
    for k in ("workflow_execution_id", "run_id"):
        v = str(data.get(k, "") or "").strip()
        if v:
            return v
    return f"run-{uuid.uuid4().hex}"


def _infer_preavaluo_id(folder_prefix: str, provided: Any) -> str:
    p = str(provided or "").strip()
    if p:
        return p
    if folder_prefix:
        return folder_prefix.split("/")[0] or "SIM-000"
    return "SIM-000"


def _json_log(payload: Dict[str, Any]) -> None:
    # Log estructurado como JSON en textPayload
    logging.info(json.dumps(payload, ensure_ascii=False))


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
    _json_log(payload)


def _error_response(
    *,
    run_id: str,
    preavaluo_id: str,
    bucket: str,
    folder_prefix: str,
    stage: str,
    code: str,
    message: str,
    details: Optional[Dict[str, Any]] = None,
    partial_results: Optional[List[Dict[str, Any]]] = None,
) -> Tuple[Any, int]:
    body: Dict[str, Any] = {
        "status": "error",
        "run_id": run_id,
        "preavaluo_id": preavaluo_id,
        "bucket": bucket,
        "folder_prefix": folder_prefix,
        "document_count": 0,
        "results": partial_results or [],
        "error": {
            "stage": stage,
            "code": code,
            "message": message,
            "details": details or {},
            "ts_utc": _utc_iso(),
        },
    }
    return jsonify(body), 500


def _success_response(
    *,
    run_id: str,
    preavaluo_id: str,
    bucket: str,
    folder_prefix: str,
    results: List[Dict[str, Any]],
    status: str,
) -> Tuple[Any, int]:
    body: Dict[str, Any] = {
        "status": status,
        "run_id": run_id,
        "preavaluo_id": preavaluo_id,
        "bucket": bucket,
        "folder_prefix": folder_prefix,
        "document_count": len(results),
        "results": results,
    }
    return jsonify(body), 200


# ─────────────────────────────────────────────────────────────
# Simuladores (blindados: no deben lanzar)
# ─────────────────────────────────────────────────────────────
def simulate_classification(file_name: str) -> Dict[str, Any]:
    categories = ["EstadoDeResultados", "BalanceGeneral", "RegistrosPatronales"]
    try:
        return {
            "document_type": random.choice(categories),
            "confidence": round(random.uniform(0.8, 0.99), 2),
        }
    except Exception:
        # fallback ultra seguro
        return {"document_type": "UNKNOWN", "confidence": 0.0}


def simulate_extraction(file_name: str, category: str) -> Dict[str, Any]:
    try:
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
    except Exception:
        return {"fields": {}, "metadata": {"decision_path": "SIMULATED_ERROR"}}


# ─────────────────────────────────────────────────────────────
# GCS (blindado)
# ─────────────────────────────────────────────────────────────
def _list_object_names(
    *,
    bucket_name: str,
    prefix: str,
    allowed_exts: Set[str],
    max_items: int,
) -> List[str]:
    # Si algo falla aquí, levantamos AppError con código específico
    try:
        client = storage.Client()
        names: List[str] = []

        for blob in client.list_blobs(bucket_name, prefix=prefix):
            name = (blob.name or "").strip()
            if not name:
                continue
            if name.endswith("/"):
                continue

            lower = name.lower()
            if allowed_exts and not any(lower.endswith(ext) for ext in allowed_exts):
                continue

            names.append(name)
            if len(names) >= max_items:
                break

        return names

    except Exception as e:
        raise AppError(
            code="GCS_LIST_FAILED",
            message="Failed to list objects from GCS.",
            stage="LIST_BUCKET",
            details={
                "bucket": bucket_name,
                "prefix": prefix,
                "exception": str(e),
            },
        )


# ─────────────────────────────────────────────────────────────
# Entry point
# ─────────────────────────────────────────────────────────────
@functions_framework.http
def document_processor(request):
    # Defaults para que SIEMPRE podamos responder con forma estable
    bucket_name = os.environ.get("BUCKET_NAME", "preavaluos-pdf")
    folder_prefix = ""
    preavaluo_id = "SIM-000"
    run_id = f"run-{uuid.uuid4().hex}"

    try:
        if request.method != "POST":
            # Según tu regla: error => 500
            return _error_response(
                run_id=run_id,
                preavaluo_id=preavaluo_id,
                bucket=bucket_name,
                folder_prefix=folder_prefix,
                stage="VALIDATION",
                code="METHOD_NOT_ALLOWED",
                message="Only POST is allowed.",
                details={"method": request.method},
            )

        data = request.get_json(silent=True)
        if not isinstance(data, dict):
            data = {}

        run_id = _make_run_id(data)
        folder_prefix = _normalize_prefix(data.get("folder_prefix", ""))
        preavaluo_id = _infer_preavaluo_id(folder_prefix, data.get("preavaluo_id"))

        # Logs iniciales
        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="START",
            percent=0,
        )

        # Validación (regla: error=>500)
        if not folder_prefix:
            raise AppError(
                code="MISSING_FOLDER_PREFIX",
                message="folder_prefix is required.",
                stage="VALIDATION",
                details={"expected": "string e.g. 'SIM-123/'"},
            )

        # Config opcional
        extensions = data.get("extensions") or [".pdf"]
        allowed_exts = {str(x).lower().strip() for x in extensions if str(x).strip()}
        max_items = _safe_int(data.get("max_items"), default=500)

        # 20%: listando bucket
        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="LIST_BUCKET_START",
            percent=20,
            extra={"max_items": max_items, "extensions": sorted(list(allowed_exts))},
        )

        object_names = _list_object_names(
            bucket_name=bucket_name,
            prefix=folder_prefix,
            allowed_exts=allowed_exts,
            max_items=max_items,
        )

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

        # Sin archivos: lo tratamos como éxito (200) con status no_files
        if total_files == 0:
            _log_progress(
                run_id=run_id,
                preavaluo_id=preavaluo_id,
                bucket=bucket_name,
                folder_prefix=folder_prefix,
                step="DONE_NO_FILES",
                percent=100,
            )
            return _success_response(
                run_id=run_id,
                preavaluo_id=preavaluo_id,
                bucket=bucket_name,
                folder_prefix=folder_prefix,
                results=[],
                status="no_files",
            )

        # 40%: clasificación
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
            try:
                classifications[name] = simulate_classification(name)
                _json_log({
                    "event_type": "progress_detail",
                    "ts_utc": _utc_iso(),
                    "run_id": run_id,
                    "step": "CLASSIFY_ITEM",
                    "current_file": idx,
                    "total_files": total_files,
                    "file_name": name,
                })
                time.sleep(0.02)
            except Exception as e:
                # Blindaje por archivo (si pasa algo raro)
                _json_log({
                    "event_type": "progress_detail",
                    "ts_utc": _utc_iso(),
                    "run_id": run_id,
                    "step": "CLASSIFY_ITEM_ERROR",
                    "file_name": name,
                    "exception": str(e),
                })
                classifications[name] = {"document_type": "UNKNOWN", "confidence": 0.0}

        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="CLASSIFY_DONE",
            percent=60,
            extra={"total_files": total_files},
        )

        # 70%: extracción
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
        had_item_errors = False

        for idx, name in enumerate(object_names, start=1):
            try:
                c = classifications.get(name) or {"document_type": "UNKNOWN", "confidence": 0.0}
                e = simulate_extraction(name, str(c.get("document_type", "UNKNOWN")))
                results.append({
                    "file_name": name,
                    "gcs_uri": f"gs://{bucket_name}/{name}",
                    "classification": c,
                    "extraction": e,
                    "processed_at": datetime.utcnow().isoformat(),
                })

                _json_log({
                    "event_type": "progress_detail",
                    "ts_utc": _utc_iso(),
                    "run_id": run_id,
                    "step": "EXTRACT_ITEM",
                    "current_file": idx,
                    "total_files": total_files,
                    "file_name": name,
                })
                time.sleep(0.02)

            except Exception as e:
                had_item_errors = True
                _json_log({
                    "event_type": "progress_detail",
                    "ts_utc": _utc_iso(),
                    "run_id": run_id,
                    "step": "EXTRACT_ITEM_ERROR",
                    "file_name": name,
                    "exception": str(e),
                })
                # Guardamos un resultado “marcado” para que el output sea consistente
                results.append({
                    "file_name": name,
                    "gcs_uri": f"gs://{bucket_name}/{name}",
                    "classification": {"document_type": "UNKNOWN", "confidence": 0.0},
                    "extraction": {"fields": {}, "metadata": {"decision_path": "SIMULATED_ERROR"}},
                    "processed_at": datetime.utcnow().isoformat(),
                    "error": {"code": "FILE_PROCESS_FAILED", "message": str(e)},
                })

        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="EXTRACT_DONE",
            percent=80,
            extra={"total_files": total_files},
        )

        # 100% done
        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="DONE",
            percent=100,
            extra={"document_count": len(results)},
        )

        # Si hubo errores por archivo, lo consideramos error global (500),
        # para cumplir “éxito=200 / error=500”.
        if had_item_errors:
            return _error_response(
                run_id=run_id,
                preavaluo_id=preavaluo_id,
                bucket=bucket_name,
                folder_prefix=folder_prefix,
                stage="PROCESSING",
                code="PARTIAL_FAILURE",
                message="Some files failed to process.",
                details={"document_count": len(results)},
                partial_results=results,
            )

        return _success_response(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            results=results,
            status="processed",
        )

    except AppError as e:
        _json_log({
            "event_type": "error",
            "ts_utc": _utc_iso(),
            "run_id": run_id,
            "stage": e.stage,
            "code": e.code,
            "message": e.message,
            "details": e.details,
        })
        return _error_response(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            stage=e.stage,
            code=e.code,
            message=e.message,
            details=e.details,
        )

    except Exception as e:
        # Catch-all blindado
        _json_log({
            "event_type": "error",
            "ts_utc": _utc_iso(),
            "run_id": run_id,
            "stage": "UNEXPECTED",
            "code": "UNEXPECTED_ERROR",
            "message": str(e),
        })
        return _error_response(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            stage="UNEXPECTED",
            code="UNEXPECTED_ERROR",
            message="Unexpected server error.",
            details={"exception": str(e)},
        )
