import os
import json
import uuid
import time
import random
import logging
import hashlib
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set, Tuple

from flask import jsonify
import functions_framework
from google.cloud import storage
from google.cloud import firestore

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
    v = str(data.get("workflow_execution_id", "") or "").strip()
    if v:
        return v
    return f"run-{uuid.uuid4().hex}"


def _make_doc_id(folio_id: str, file_id: str) -> str:
    """Genera un ID único y determinístico para el documento."""
    combined = f"{folio_id}:{file_id}"
    return hashlib.sha256(combined.encode()).hexdigest()[:16]


def _is_valid_pdf(blob_name: str, storage_client: storage.Client, bucket_name: str) -> Tuple[bool, str]:
    """Valida si un objeto en GCS es un PDF válido leyendo sus magic bytes.
    
    Returns:
        Tuple[bool, str]: (es_valido, mensaje_error)
    """
    try:
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        
        # Leer primeros 5 bytes para verificar magic number de PDF: %PDF-
        header = blob.download_as_bytes(start=0, end=5)
        
        if header == b'%PDF-':
            return True, ""
        else:
            return False, f"Invalid PDF header. Expected '%PDF-', got: {header[:10]}"
            
    except Exception as e:
        return False, f"Error reading file: {str(e)}"


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
# Simuladores Document AI (blindados: no deben lanzar)
# ─────────────────────────────────────────────────────────────
def simulate_classification(file_name: str) -> Dict[str, Any]:
    """Simula clasificador de Document AI con 3 categorías de estados financieros.
    
    Categorías:
    - ESTADO_RESULTADOS: Estado de Resultados / Profit & Loss
    - ESTADO_SITUACION_FINANCIERA: Balance General / Statement of Financial Position
    - ESTADO_FLUJOS_EFECTIVO: Estado de Flujos de Efectivo / Cash Flow Statement
    """
    categories = [
        "ESTADO_RESULTADOS",
        "ESTADO_SITUACION_FINANCIERA", 
        "ESTADO_FLUJOS_EFECTIVO"
    ]
    try:
        doc_type = random.choice(categories)
        return {
            "document_type": doc_type,
            "confidence": round(random.uniform(0.85, 0.99), 3),
            "classifier_version": "document-ai-classifier-v1",
        }
    except Exception:
        return {"document_type": "UNKNOWN", "confidence": 0.0, "classifier_version": "error"}


def simulate_extraction(file_name: str, category: str) -> Dict[str, Any]:
    """Simula extractor de Document AI según el tipo de documento clasificado.
    
    Extrae campos estructurados según el esquema de Document AI:
    - LINE_ITEM_NAME, LINE_ITEM_VALUE, COLUMN_YEAR
    - SECTION_HEADER, TOTAL_LABEL, CURRENCY, UNITS_SCALE
    - REPORTING_PERIOD, ORG_NAME, STATEMENT_TITLE
    - TABLE_COLUMN_HEADER, TABLE_ROW_REF, TABLE_CELL_REF
    """
    try:
        # Campos comunes para todos los documentos
        common_fields = {
            "ORG_NAME": "Apolo Solutions S.A. de C.V.",
            "REPORTING_PERIOD": f"{random.randint(2020, 2024)}-12-31",
            "CURRENCY": "MXN",
            "UNITS_SCALE": random.choice(["MILES", "MILLONES", "UNIDADES"]),
        }
        
        # Simular años para columnas
        base_year = random.randint(2020, 2024)
        years = [str(base_year - 1), str(base_year)]
        
        # Campos específicos por tipo de documento
        if category == "ESTADO_RESULTADOS":
            line_items = [
                {"LINE_ITEM_NAME": "Ventas Netas", "LINE_ITEM_VALUE": round(random.uniform(1000000, 5000000), 2), "COLUMN_YEAR": years[1]},
                {"LINE_ITEM_NAME": "Costo de Ventas", "LINE_ITEM_VALUE": round(random.uniform(500000, 2000000), 2), "COLUMN_YEAR": years[1]},
                {"LINE_ITEM_NAME": "Utilidad Bruta", "LINE_ITEM_VALUE": round(random.uniform(500000, 3000000), 2), "COLUMN_YEAR": years[1], "TOTAL_LABEL": "SUBTOTAL"},
                {"LINE_ITEM_NAME": "Gastos de Operación", "LINE_ITEM_VALUE": round(random.uniform(200000, 1000000), 2), "COLUMN_YEAR": years[1]},
                {"LINE_ITEM_NAME": "EBITDA", "LINE_ITEM_VALUE": round(random.uniform(300000, 2000000), 2), "COLUMN_YEAR": years[1], "TOTAL_LABEL": "TOTAL"},
                {"LINE_ITEM_NAME": "Utilidad Neta", "LINE_ITEM_VALUE": round(random.uniform(100000, 1500000), 2), "COLUMN_YEAR": years[1], "TOTAL_LABEL": "TOTAL"},
            ]
            common_fields.update({
                "STATEMENT_TITLE": "Estado de Resultados",
                "line_items": line_items,
            })
            
        elif category == "ESTADO_SITUACION_FINANCIERA":
            line_items = [
                {"LINE_ITEM_NAME": "Efectivo y Equivalentes", "LINE_ITEM_VALUE": round(random.uniform(100000, 1000000), 2), "COLUMN_YEAR": years[1], "SECTION_HEADER": "ACTIVO CIRCULANTE"},
                {"LINE_ITEM_NAME": "Cuentas por Cobrar", "LINE_ITEM_VALUE": round(random.uniform(200000, 1500000), 2), "COLUMN_YEAR": years[1]},
                {"LINE_ITEM_NAME": "Inventarios", "LINE_ITEM_VALUE": round(random.uniform(300000, 2000000), 2), "COLUMN_YEAR": years[1]},
                {"LINE_ITEM_NAME": "Total Activo Circulante", "LINE_ITEM_VALUE": round(random.uniform(600000, 4500000), 2), "COLUMN_YEAR": years[1], "TOTAL_LABEL": "SUBTOTAL"},
                {"LINE_ITEM_NAME": "Activo Fijo", "LINE_ITEM_VALUE": round(random.uniform(1000000, 5000000), 2), "COLUMN_YEAR": years[1], "SECTION_HEADER": "ACTIVO NO CIRCULANTE"},
                {"LINE_ITEM_NAME": "Total Activo", "LINE_ITEM_VALUE": round(random.uniform(2000000, 10000000), 2), "COLUMN_YEAR": years[1], "TOTAL_LABEL": "TOTAL"},
                {"LINE_ITEM_NAME": "Pasivo Total", "LINE_ITEM_VALUE": round(random.uniform(800000, 4000000), 2), "COLUMN_YEAR": years[1], "SECTION_HEADER": "PASIVO"},
                {"LINE_ITEM_NAME": "Capital Contable", "LINE_ITEM_VALUE": round(random.uniform(1200000, 6000000), 2), "COLUMN_YEAR": years[1], "SECTION_HEADER": "CAPITAL"},
            ]
            common_fields.update({
                "STATEMENT_TITLE": "Estado de Situación Financiera",
                "line_items": line_items,
            })
            
        elif category == "ESTADO_FLUJOS_EFECTIVO":
            line_items = [
                {"LINE_ITEM_NAME": "Flujos de Operación", "LINE_ITEM_VALUE": round(random.uniform(200000, 1500000), 2), "COLUMN_YEAR": years[1], "SECTION_HEADER": "ACTIVIDADES DE OPERACION"},
                {"LINE_ITEM_NAME": "Flujos de Inversión", "LINE_ITEM_VALUE": round(random.uniform(-500000, -100000), 2), "COLUMN_YEAR": years[1], "SECTION_HEADER": "ACTIVIDADES DE INVERSION"},
                {"LINE_ITEM_NAME": "Flujos de Financiamiento", "LINE_ITEM_VALUE": round(random.uniform(-300000, 300000), 2), "COLUMN_YEAR": years[1], "SECTION_HEADER": "ACTIVIDADES DE FINANCIAMIENTO"},
                {"LINE_ITEM_NAME": "Incremento Neto en Efectivo", "LINE_ITEM_VALUE": round(random.uniform(50000, 500000), 2), "COLUMN_YEAR": years[1], "TOTAL_LABEL": "TOTAL"},
            ]
            common_fields.update({
                "STATEMENT_TITLE": "Estado de Flujos de Efectivo",
                "line_items": line_items,
            })
        else:
            # Fallback para tipos desconocidos
            line_items = []
            common_fields.update({
                "STATEMENT_TITLE": "Documento No Clasificado",
                "line_items": line_items,
            })

        # Metadata de Document AI
        metadata = {
            "page_count": random.randint(1, 5),
            "processor_version": "projects/PROJECT_ID/locations/us/processors/PROCESSOR_ID/processorVersions/VERSION_ID",
            "extraction_schema_version": "v1.0",
            "mime_type": "application/pdf",
            "decision_path": "DOCUMENT_AI",
            "table_references": [
                {
                    "TABLE_COLUMN_HEADER": years,
                    "TABLE_ROW_REF": [item["LINE_ITEM_NAME"] for item in line_items[:5]],
                }
            ],
        }
        
        return {"fields": common_fields, "metadata": metadata}
        
    except Exception as e:
        logging.error(f"Error in simulate_extraction: {e}")
        return {"fields": {}, "metadata": {"decision_path": "SIMULATED_ERROR", "error": str(e)}}


# ─────────────────────────────────────────────────────────────
# Firestore (persistencia e idempotencia)
# ─────────────────────────────────────────────────────────────
def _get_firestore_client() -> firestore.Client:
    """Obtiene cliente de Firestore con la base de datos configurada."""
    database_id = os.environ.get("FIRESTORE_DATABASE", "(default)")
    return firestore.Client(database=database_id)


def _ensure_run_document(
    db: firestore.Client,
    run_id: str,
    preavaluo_id: str,
    bucket_name: str,
    folder_prefix: str,
) -> None:
    """Crea o actualiza el documento de corrimiento (run) en Firestore.
    
    Estructura: runs/{runId}
    """
    try:
        run_ref = db.collection("runs").document(run_id)
        run_doc = run_ref.get()
        
        if not run_doc.exists:
            # Crear documento de run
            run_ref.set({
                "runId": run_id,
                "preavaluo_id": preavaluo_id,
                "sourceBucket": f"gs://{bucket_name}",
                "folderPrefix": folder_prefix,
                "status": "processing",
                "documentCount": 0,
                "processedCount": 0,
                "failedCount": 0,
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })
        else:
            # Actualizar timestamp
            run_ref.update({
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "status": "processing",
            })
    except Exception as e:
        logging.error(f"Error ensuring run document: {e}")


def _check_and_acquire_lease(
    db: firestore.Client,
    run_id: str,
    doc_id: str,
    folio_id: str,
    file_id: str,
    gcs_uri: str,
) -> Tuple[bool, Optional[Dict[str, Any]]]:
    """Verifica si el documento ya fue procesado o adquiere lease para procesarlo.
    
    Estructura: runs/{runId}/documents/{docId}
    
    Returns:
        Tuple[bool, Optional[Dict]]: (puede_procesar, resultado_existente)
    """
    try:
        doc_ref = db.collection("runs").document(run_id).collection("documents").document(doc_id)
        doc = doc_ref.get()
        
        if doc.exists:
            data = doc.to_dict()
            if data is None:
                data = {}
            status = data.get("status")
            
            # Si ya está procesado exitosamente, retornar resultado desde cache
            if status == "completed":
                logging.info(f"Document {doc_id} already processed (cache hit)")
                return False, data
            
            # Si está en proceso pero hace más de 10 min, permitir reintentar
            if status == "processing":
                processing_since = data.get("processingStartedAt") if data else None
                if processing_since:
                    elapsed = (datetime.now(timezone.utc) - processing_since).total_seconds()
                    if elapsed < 600:  # 10 minutos
                        logging.warning(f"Document {doc_id} still processing (lease active)")
                        return False, {"status": "already_processing", "runId": data.get("runId") if data else None}
        
        # Adquirir lease
        doc_ref.set({
            "docId": doc_id,
            "runId": run_id,
            "folioId": folio_id,
            "fileId": file_id,
            "gcsUri": gcs_uri,
            "status": "processing",
            "processingStartedAt": firestore.SERVER_TIMESTAMP,
            "createdAt": firestore.SERVER_TIMESTAMP,
        }, merge=True)
        
        logging.info(f"Lease acquired for document {doc_id}")
        return True, None
        
    except Exception as e:
        logging.error(f"Error checking/acquiring lease: {e}")
        # En caso de error, permitir procesamiento (fail-open)
        return True, None


def _persist_result(
    db: firestore.Client,
    run_id: str,
    doc_id: str,
    folio_id: str,
    file_id: str,
    gcs_uri: str,
    classification: Dict[str, Any],
    extraction: Dict[str, Any],
    status: str = "completed",
    error: Optional[Dict[str, Any]] = None,
) -> None:
    """Persiste el resultado del procesamiento Document AI en Firestore.
    
    Estructura jerárquica:
    runs/{runId}/documents/{docId}
    
    Campos guardados:
    - Clasificación (document_type, confidence, classifier_version)
    - Extracción (fields completos según tipo de documento)
    - Metadata de Document AI (processor_version, extraction_schema_version)
    - Timestamps y status
    """
    try:
        # Referencia al documento dentro del run
        doc_ref = db.collection("runs").document(run_id).collection("documents").document(doc_id)
        
        # Preparar documento con toda la información
        result = {
            "docId": doc_id,
            "runId": run_id,
            "folioId": folio_id,
            "fileId": file_id,
            "gcsUri": gcs_uri,
            "status": status,
            
            # Clasificación de Document AI
            "classification": {
                "documentType": classification.get("document_type", "UNKNOWN"),
                "confidence": classification.get("confidence", 0.0),
                "classifierVersion": classification.get("classifier_version", "unknown"),
            },
            
            # Extracción completa de Document AI
            "extraction": {
                "fields": extraction.get("fields", {}),
                "metadata": extraction.get("metadata", {}),
            },
            
            # Timestamps
            "processedAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        
        # Agregar error si existe
        if error:
            result["error"] = error
            result["status"] = "failed"
        
        # Guardar documento
        doc_ref.set(result, merge=True)
        
        # Actualizar contadores en el run principal
        run_ref = db.collection("runs").document(run_id)
        if status == "completed":
            run_ref.update({
                "processedCount": firestore.Increment(1),
                "documentCount": firestore.Increment(1),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })
        elif status == "failed":
            run_ref.update({
                "failedCount": firestore.Increment(1),
                "documentCount": firestore.Increment(1),
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })
        
        logging.info(f"Document {doc_id} persisted successfully with status: {status}")
        
    except Exception as e:
        logging.error(f"Error persisting result to Firestore: {e}")
        # No levantamos excepción para no fallar el procesamiento completo


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
def document_processor(request: Any):
    # Defaults para que SIEMPRE podamos responder con forma estable
    bucket_name = os.environ.get("BUCKET_NAME", "preavaluos-pdf")
    folder_prefix = ""
    preavaluo_id = "SIM-000"
    run_id = f"run-{uuid.uuid4().hex}"
    folio_id = ""
    file_id = ""

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

        # Parámetros según spec: folioId, fileId, gcs_pdf_uri, workflow_execution_id
        run_id = _make_run_id(data)
        folio_id = str(data.get("folioId", "") or "").strip()
        file_id = str(data.get("fileId", "") or "").strip()
        gcs_pdf_uri = str(data.get("gcs_pdf_uri", "") or "").strip()
        
        # Mantener compatibilidad con folder_prefix para listar múltiples archivos
        folder_prefix = _normalize_prefix(data.get("folder_prefix", ""))
        preavaluo_id = folio_id or _infer_preavaluo_id(folder_prefix, data.get("preavaluo_id"))

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
        # Dos modos: procesamiento individual (gcs_pdf_uri) o batch (folder_prefix)
        if not gcs_pdf_uri and not folder_prefix:
            raise AppError(
                code="MISSING_REQUIRED_PARAMS",
                message="Either gcs_pdf_uri or folder_prefix is required.",
                stage="VALIDATION",
                details={"expected": "gcs_pdf_uri (individual) or folder_prefix (batch)"},
            )
        
        # Si es procesamiento individual, validar parámetros completos
        if gcs_pdf_uri and (not folio_id or not file_id):
            raise AppError(
                code="MISSING_REQUIRED_PARAMS",
                message="folioId and fileId are required when using gcs_pdf_uri.",
                stage="VALIDATION",
                details={"provided": {"folioId": folio_id, "fileId": file_id}},
            )

        # Inicializar clientes
        storage_client = storage.Client()
        db = _get_firestore_client()
        
        # Crear/actualizar documento de run en Firestore
        _ensure_run_document(db, run_id, preavaluo_id, bucket_name, folder_prefix)
        
        # Modo individual: procesar un solo documento
        if gcs_pdf_uri:
            # Extraer bucket y blob name de gs://bucket/path/file.pdf
            if not gcs_pdf_uri.startswith("gs://"):
                raise AppError(
                    code="INVALID_GCS_URI",
                    message="gcs_pdf_uri must start with gs://",
                    stage="VALIDATION",
                    details={"provided": gcs_pdf_uri},
                )
            
            parts = gcs_pdf_uri[5:].split("/", 1)
            if len(parts) != 2:
                raise AppError(
                    code="INVALID_GCS_URI",
                    message="Invalid gcs_pdf_uri format",
                    stage="VALIDATION",
                    details={"provided": gcs_pdf_uri},
                )
            
            bucket_name = parts[0]
            blob_name = parts[1]
            object_names = [blob_name]
            
        else:
            # Modo batch: listar archivos del folder
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

        # 30%: validación de PDFs
        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="VALIDATE_PDF_START",
            percent=30,
            extra={"total_files": total_files},
        )
        
        valid_pdfs: List[str] = []
        invalid_files: List[Dict[str, Any]] = []
        
        for idx, name in enumerate(object_names, start=1):
            is_valid, error_msg = _is_valid_pdf(name, storage_client, bucket_name)
            
            if is_valid:
                valid_pdfs.append(name)
            else:
                _json_log({
                    "event_type": "progress_detail",
                    "ts_utc": _utc_iso(),
                    "run_id": run_id,
                    "step": "INVALID_PDF",
                    "file_name": name,
                    "error": error_msg,
                })
                invalid_files.append({
                    "file_name": name,
                    "error": {"code": "INVALID_PDF_FORMAT", "message": error_msg},
                })
        
        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="VALIDATE_PDF_DONE",
            percent=35,
            extra={"valid_pdfs": len(valid_pdfs), "invalid_files": len(invalid_files)},
        )
        
        # Si no hay PDFs válidos, retornar error
        if len(valid_pdfs) == 0:
            return _error_response(
                run_id=run_id,
                preavaluo_id=preavaluo_id,
                bucket=bucket_name,
                folder_prefix=folder_prefix,
                stage="VALIDATION",
                code="NO_VALID_PDFS",
                message="No valid PDF files found.",
                details={"invalid_files": invalid_files},
            )

        # 40%: clasificación
        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="CLASSIFY_START",
            percent=40,
            extra={"total_files": len(valid_pdfs)},
        )

        classifications: Dict[str, Dict[str, Any]] = {}
        for idx, name in enumerate(valid_pdfs, start=1):
            try:
                classifications[name] = simulate_classification(name)
                _json_log({
                    "event_type": "progress_detail",
                    "ts_utc": _utc_iso(),
                    "run_id": run_id,
                    "step": "CLASSIFY_ITEM",
                    "current_file": idx,
                    "total_files": len(valid_pdfs),
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
            extra={"total_files": len(valid_pdfs)},
        )

        # 70%: extracción y persistencia
        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="EXTRACT_START",
            percent=70,
            extra={"total_files": len(valid_pdfs)},
        )

        results: List[Dict[str, Any]] = []
        had_item_errors = False

        for idx, name in enumerate(valid_pdfs, start=1):
            try:
                # Generar ID único para este documento
                current_folio = folio_id if folio_id else preavaluo_id
                current_file_id = file_id if file_id else name.split("/")[-1]
                doc_id = _make_doc_id(current_folio, current_file_id)
                gcs_uri = f"gs://{bucket_name}/{name}"
                
                # Verificar si ya fue procesado (idempotencia)
                can_process, cached_result = _check_and_acquire_lease(
                    db, run_id, doc_id, current_folio, current_file_id, gcs_uri
                )
                
                if not can_process and cached_result and cached_result.get("status") == "completed":
                    # Usar resultado desde cache
                    results.append({
                        "file_name": name,
                        "gcs_uri": gcs_uri,
                        "classification": cached_result.get("classification", {}),
                        "extraction": cached_result.get("extraction", {}),
                        "processed_at": cached_result.get("processedAt", _utc_iso()),
                        "from_cache": True,
                    })
                    logging.info(f"Using cached result for {name}")
                    continue
                
                # Procesar documento nuevo
                c = classifications.get(name) or {"document_type": "UNKNOWN", "confidence": 0.0}
                e = simulate_extraction(name, str(c.get("document_type", "UNKNOWN")))
                
                # Persistir en Firestore
                _persist_result(
                    db=db,
                    run_id=run_id,
                    doc_id=doc_id,
                    folio_id=current_folio,
                    file_id=current_file_id,
                    gcs_uri=gcs_uri,
                    classification=c,
                    extraction=e,
                    status="completed",
                )
                
                results.append({
                    "file_name": name,
                    "gcs_uri": gcs_uri,
                    "classification": c,
                    "extraction": e,
                    "processed_at": datetime.now(timezone.utc).isoformat(),
                    "from_cache": False,
                })

                _json_log({
                    "event_type": "progress_detail",
                    "ts_utc": _utc_iso(),
                    "run_id": run_id,
                    "step": "EXTRACT_ITEM",
                    "current_file": idx,
                    "total_files": total_files,
                    "file_name": name,
                    "doc_id": doc_id,
                })
                time.sleep(0.02)

            except Exception as e:
                had_item_errors = True
                current_folio = folio_id if folio_id else preavaluo_id
                current_file_id = file_id if file_id else name.split("/")[-1]
                doc_id = _make_doc_id(current_folio, current_file_id)
                gcs_uri = f"gs://{bucket_name}/{name}"
                
                _json_log({
                    "event_type": "progress_detail",
                    "ts_utc": _utc_iso(),
                    "run_id": run_id,
                    "step": "EXTRACT_ITEM_ERROR",
                    "file_name": name,
                    "doc_id": doc_id,
                    "exception": str(e),
                })
                
                # Persistir error en Firestore
                _persist_result(
                    db=db,
                    run_id=run_id,
                    doc_id=doc_id,
                    folio_id=current_folio,
                    file_id=current_file_id,
                    gcs_uri=gcs_uri,
                    classification={"document_type": "UNKNOWN", "confidence": 0.0},
                    extraction={"fields": {}, "metadata": {"decision_path": "ERROR"}},
                    status="failed",
                    error={"code": "FILE_PROCESS_FAILED", "message": str(e)},
                )
                
                # Guardamos un resultado "marcado" para que el output sea consistente
                results.append({
                    "file_name": name,
                    "gcs_uri": gcs_uri,
                    "classification": {"document_type": "UNKNOWN", "confidence": 0.0},
                    "extraction": {"fields": {}, "metadata": {"decision_path": "ERROR"}},
                    "processed_at": datetime.now(timezone.utc).isoformat(),
                    "from_cache": False,
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

        # 100% done - Actualizar run a completado
        try:
            run_ref = db.collection("runs").document(run_id)
            run_ref.update({
                "status": "completed" if not had_item_errors else "partial_failure",
                "updatedAt": firestore.SERVER_TIMESTAMP,
            })
        except Exception as e:
            logging.error(f"Error updating run status: {e}")
        
        _log_progress(
            run_id=run_id,
            preavaluo_id=preavaluo_id,
            bucket=bucket_name,
            folder_prefix=folder_prefix,
            step="DONE",
            percent=100,
            extra={"document_count": len(results), "had_errors": had_item_errors},
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
