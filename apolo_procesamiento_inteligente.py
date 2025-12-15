"""
Apolo Document Processing Microservice - Procesamiento Inteligente de Preavalúos

Arquitectura alineada con especificación:
- Serverless Cloud Run service activado por Eventarc en eventos de GCS
- Trigger: archivo sentinel 'is_ready' (0 bytes, sin extensión)
- Procesamiento paralelo de documentos con Document AI (Classifier + Extractor)
- Idempotencia completa usando GCS generation + content hashing
- Persistencia en Firestore: folios/{folioId}/documentos/{docId}/extracciones/{extractionId}
- DLQ integration para documentos fallidos via Pub/Sub
- Reintentos con backoff exponencial

Patrón de Activación:
- Eventarc escucha eventos 'object.finalize' de GCS
- Trigger solo en archivo 'is_ready' sentinel
- Procesa todos los PDFs en la carpeta automáticamente
- Idempotencia por carpeta y por documento (generation)
"""

import os
import json
import uuid
import time
import hashlib
import asyncio
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed

from flask import jsonify
import functions_framework
from google.cloud import storage
from google.cloud import firestore
from google.cloud import documentai_v1 as documentai
from google.cloud import pubsub_v1

import logging
logging.basicConfig(level=logging.INFO, force=True)
logger = logging.getLogger(__name__)

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION: Variables de entorno para servicios GCP y límites de procesamiento
# ═══════════════════════════════════════════════════════════════════════════════
PROJECT_ID = os.environ.get("GCP_PROJECT_ID", "")
LOCATION = os.environ.get("PROCESSOR_LOCATION", "us")
CLASSIFIER_PROCESSOR_ID = os.environ.get("CLASSIFIER_PROCESSOR_ID", "")
EXTRACTOR_PROCESSOR_ID = os.environ.get("EXTRACTOR_PROCESSOR_ID", "")
DLQ_TOPIC_NAME = os.environ.get("DLQ_TOPIC_NAME", "apolo-preavaluo-dlq")
MAX_CONCURRENT_DOCS = int(os.environ.get("MAX_CONCURRENT_DOCS", "8"))
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "3"))
RETRY_INITIAL_DELAY = float(os.environ.get("RETRY_INITIAL_DELAY", "1.0"))
RETRY_MULTIPLIER = float(os.environ.get("RETRY_MULTIPLIER", "2.0"))
RETRY_MAX_DELAY = float(os.environ.get("RETRY_MAX_DELAY", "60.0"))
FIRESTORE_DATABASE = os.environ.get("FIRESTORE_DATABASE", "(default)")


# ═══════════════════════════════════════════════════════════════════════════════
# DOMAIN MODEL: Error handling
# ═══════════════════════════════════════════════════════════════════════════════
class AppError(Exception):
    def __init__(self, code: str, message: str, *, stage: str, details: Optional[Dict[str, Any]] = None):
        super().__init__(message)
        self.code = code
        self.message = message
        self.stage = stage
        self.details = details or {}


# ═══════════════════════════════════════════════════════════════════════════════
# UTILITIES: Funciones auxiliares
# ═══════════════════════════════════════════════════════════════════════════════
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


def _make_folio_id(bucket: str, folder_prefix: str) -> str:
    """Genera folio_id a partir del bucket y folder_prefix."""
    if folder_prefix:
        # Usar el primer segmento del folder_prefix como ID
        parts = folder_prefix.strip("/").split("/")
        return parts[0] if parts else f"FOLIO-{uuid.uuid4().hex[:8]}"
    return f"FOLIO-{uuid.uuid4().hex[:8]}"


def _make_doc_id(folio_id: str, file_id: str, generation: Optional[str] = None) -> str:
    """Genera ID determinístico con folio + file + generation para idempotencia."""
    if generation:
        combined = f"{folio_id}:{file_id}:{generation}"
    else:
        combined = f"{folio_id}:{file_id}"
    return hashlib.sha256(combined.encode()).hexdigest()[:16]


def _exponential_backoff_delay(attempt: int) -> float:
    """Calcula delay con backoff exponencial."""
    delay = RETRY_INITIAL_DELAY * (RETRY_MULTIPLIER ** attempt)
    return min(delay, RETRY_MAX_DELAY)


def _json_log(payload: Dict[str, Any]) -> None:
    """Logging estructurado en JSON para Cloud Logging."""
    logging.info(json.dumps(payload, ensure_ascii=False))


def _parse_eventarc_event(request: Any) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """Parse Eventarc CloudEvent para extraer detalles del evento de GCS.
    
    Returns:
        (bucket_name, object_name, event_id) o (None, None, None)
    """
    try:
        event_data = request.get_json()
        if not event_data:
            return None, None, None
            
        event_id = event_data.get("id", "")
        data = event_data.get("data", {})
        bucket_name = data.get("bucket", "")
        object_name = data.get("name", "")
        
        if not bucket_name or not object_name:
            return None, None, None
            
        return bucket_name, object_name, event_id
    except Exception as e:
        logger.error(f"Error parsing Eventarc event: {e}")
        return None, None, None


def _is_ready_sentinel(object_name: str) -> Tuple[bool, str]:
    """Valida si el objeto es un archivo sentinel 'is_ready' válido.
    
    Reglas:
    - Debe terminar en '/is_ready' o ser exactamente 'is_ready'
    - Sin extensión
    
    Returns:
        (is_valid, folder_prefix)
    """
    if not object_name:
        return False, ""
    
    if object_name.endswith("/is_ready"):
        folder_prefix = object_name[:-9]  # Remove '/is_ready'
        return True, folder_prefix
    elif object_name == "is_ready":
        return True, ""
    
    return False, ""


def _publish_to_dlq(folio_id: str, gcs_uri: str, error_type: str, error_message: str,
                    attempts: int, details: Optional[Dict[str, Any]] = None) -> None:
    """Publica documento fallido al Dead Letter Queue para revisión manual."""
    try:
        if not PROJECT_ID or not DLQ_TOPIC_NAME:
            logger.warning("DLQ not configured, skipping publish")
            return
            
        publisher = pubsub_v1.PublisherClient()
        topic_path = publisher.topic_path(PROJECT_ID, DLQ_TOPIC_NAME)
        
        message_data = {
            "folio_id": folio_id,
            "gcs_uri": gcs_uri,
            "error_type": error_type,
            "error_message": error_message,
            "attempts": attempts,
            "timestamp": _utc_iso(),
            "details": details or {},
        }
        
        message_bytes = json.dumps(message_data).encode("utf-8")
        future = publisher.publish(topic_path, message_bytes)
        future.result(timeout=5.0)
        
        logger.info(f"Published to DLQ: {gcs_uri}")
    except Exception as e:
        logger.error(f"Failed to publish to DLQ: {e}")


# ═══════════════════════════════════════════════════════════════════════════════
# GCS INTEGRATION
# ═══════════════════════════════════════════════════════════════════════════════
def _list_pdfs_in_folder(bucket_name: str, folder_prefix: str) -> List[Tuple[str, str]]:
    """Lista todos los PDFs en una carpeta de GCS con sus generation numbers.
    
    Returns:
        List[(blob_name, generation)]
    """
    try:
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blobs = bucket.list_blobs(prefix=folder_prefix)
        
        pdfs = []
        for blob in blobs:
            if blob.name.lower().endswith(".pdf") and not blob.name.endswith("/"):
                pdfs.append((blob.name, str(blob.generation)))
        
        return pdfs
    except Exception as e:
        logger.error(f"Error listing PDFs: {e}")
        raise AppError(
            code="GCS_LIST_ERROR",
            message=f"Failed to list PDFs in folder: {e}",
            stage="LIST_FOLDER",
            details={"bucket": bucket_name, "folder_prefix": folder_prefix}
        )


def _is_valid_pdf(blob_name: str, storage_client: storage.Client, bucket_name: str) -> Tuple[bool, str]:
    """Valida PDF mediante magic bytes (%PDF-)."""
    try:
        bucket = storage_client.bucket(bucket_name)
        blob = bucket.blob(blob_name)
        header = blob.download_as_bytes(start=0, end=5)
        
        if header == b'%PDF-':
            return True, ""
        else:
            return False, f"Invalid PDF header. Expected '%PDF-', got: {header[:10]}"
    except Exception as e:
        return False, f"Error reading file: {str(e)}"


# ═══════════════════════════════════════════════════════════════════════════════
# DOCUMENT AI INTEGRATION con reintentos
# ═══════════════════════════════════════════════════════════════════════════════
def _process_document_ai_with_retry(processor_name: str, gcs_uri: str) -> Optional[documentai.Document]:
    """Procesa documento con Document AI con reintentos automáticos."""
    if not PROJECT_ID or not processor_name:
        logger.warning("Document AI not configured")
        return None
        
    client = documentai.DocumentProcessorServiceClient()
    
    for attempt in range(MAX_RETRIES):
        try:
            # Leer documento desde GCS
            storage_client = storage.Client()
            bucket_name, blob_name = gcs_uri.replace("gs://", "").split("/", 1)
            bucket = storage_client.bucket(bucket_name)
            blob = bucket.blob(blob_name)
            content = blob.download_as_bytes()
            
            raw_document = documentai.RawDocument(content=content, mime_type="application/pdf")
            request = documentai.ProcessRequest(name=processor_name, raw_document=raw_document)
            
            result = client.process_document(request=request)
            return result.document
            
        except Exception as e:
            logger.warning(f"Document AI attempt {attempt + 1}/{MAX_RETRIES} failed: {e}")
            if attempt < MAX_RETRIES - 1:
                delay = _exponential_backoff_delay(attempt)
                logger.info(f"Retrying in {delay:.2f} seconds...")
                time.sleep(delay)
            else:
                logger.error(f"Document AI failed after {MAX_RETRIES} attempts")
                return None
    
    return None


def classify_document(gcs_uri: str) -> Dict[str, Any]:
    """Clasifica documento usando Document AI Classifier."""
    try:
        if not CLASSIFIER_PROCESSOR_ID:
            return {"document_type": "UNKNOWN", "confidence": 0.0, "classifier_version": "not_configured"}
        
        processor_name = f"projects/{PROJECT_ID}/locations/{LOCATION}/processors/{CLASSIFIER_PROCESSOR_ID}"
        document = _process_document_ai_with_retry(processor_name, gcs_uri)
        
        if not document:
            return {"document_type": "UNKNOWN", "confidence": 0.0, "classifier_version": "error"}
        
        doc_type = "UNKNOWN"
        confidence = 0.0
        
        for entity in document.entities:
            if entity.type_ in ["ESTADO_RESULTADOS", "ESTADO_SITUACION_FINANCIERA", "ESTADO_FLUJOS_EFECTIVO"]:
                doc_type = entity.type_
                confidence = entity.confidence
                break
        
        return {
            "document_type": doc_type,
            "confidence": round(confidence, 3),
            "classifier_version": processor_name,
        }
    except Exception as e:
        logger.error(f"Classification error: {e}")
        return {"document_type": "UNKNOWN", "confidence": 0.0, "classifier_version": "error"}


def extract_document_data(gcs_uri: str, doc_type: str) -> Dict[str, Any]:
    """Extrae datos estructurados con Document AI Extractor con trazabilidad completa."""
    try:
        if not EXTRACTOR_PROCESSOR_ID:
            return _generate_fallback_extraction()
        
        processor_name = f"projects/{PROJECT_ID}/locations/{LOCATION}/processors/{EXTRACTOR_PROCESSOR_ID}"
        document = _process_document_ai_with_retry(processor_name, gcs_uri)
        
        if not document:
            return _generate_fallback_extraction()
        
        fields = {}
        line_items = []
        
        for entity in document.entities:
            text_value = entity.mention_text if hasattr(entity, 'mention_text') else ""
            confidence = entity.confidence if hasattr(entity, 'confidence') else 0.0
            
            # Extraer page_refs y bounding boxes
            page_refs = []
            if hasattr(entity, 'page_anchor') and entity.page_anchor:
                for page_ref in entity.page_anchor.page_refs:
                    page_info = {"page": page_ref.page if hasattr(page_ref, 'page') else 0}
                    if hasattr(page_ref, 'bounding_poly') and page_ref.bounding_poly:
                        vertices = [{"x": v.x, "y": v.y} for v in page_ref.bounding_poly.normalized_vertices]
                        page_info["bounding_box"] = vertices
                    page_refs.append(page_info)
            
            field_data = {
                "value": text_value,
                "confidence": round(confidence, 3),
                "page_refs": page_refs,
            }
            
            # Organizar por tipo de entidad
            entity_type = entity.type_
            if entity_type in ["LINE_ITEM_NAME", "LINE_ITEM_VALUE", "COLUMN_YEAR",
                              "SECTION_HEADER", "TOTAL_LABEL"]:
                line_items.append({"type": entity_type, **field_data})
            else:
                fields[entity_type] = field_data
        
        if line_items:
            fields["line_items"] = line_items
        
        return {
            "fields": fields,
            "metadata": {
                "page_count": len(document.pages) if hasattr(document, 'pages') else 0,
                "processor_version": processor_name,
                "extraction_schema_version": "v1.0",
            }
        }
    except Exception as e:
        logger.error(f"Extraction error: {e}")
        return _generate_fallback_extraction()


def _generate_fallback_extraction() -> Dict[str, Any]:
    """Genera extracción mínima cuando Document AI no está disponible."""
    return {
        "fields": {},
        "metadata": {
            "page_count": 0,
            "processor_version": "fallback",
            "extraction_schema_version": "v1.0",
        }
    }


# ═══════════════════════════════════════════════════════════════════════════════
# FIRESTORE PERSISTENCE: Esquema jerárquico según spec
# folios/{folioId}/documentos/{docId}/extracciones/{extractionId}
# ═══════════════════════════════════════════════════════════════════════════════
def _get_firestore_client() -> firestore.Client:
    return firestore.Client(database=FIRESTORE_DATABASE)


def _ensure_folio_document(db: firestore.Client, folio_id: str, bucket: str, folder_prefix: str) -> None:
    """Crea o actualiza documento de folio en Firestore."""
    try:
        folio_ref = db.collection("folios").document(folio_id)
        folio_doc = folio_ref.get()
        
        if not folio_doc.exists:
            folio_ref.set({
                "bucket": bucket,
                "folder_prefix": folder_prefix,
                "status": "PROCESSING",
                "total_docs": 0,
                "processed_docs": 0,
                "created_at": firestore.SERVER_TIMESTAMP,
                "started_at": firestore.SERVER_TIMESTAMP,
            })
        else:
            folio_ref.update({
                "status": "PROCESSING",
                "started_at": firestore.SERVER_TIMESTAMP,
                "last_update_at": firestore.SERVER_TIMESTAMP,
            })
    except Exception as e:
        logger.error(f"Error creating folio document: {e}")


def _check_document_processed(db: firestore.Client, folio_id: str, doc_id: str) -> Tuple[bool, Optional[Dict]]:
    """Verifica si un documento ya fue procesado (idempotencia).
    
    Returns:
        (already_processed, cached_data)
    """
    try:
        doc_ref = db.collection("folios").document(folio_id).collection("documentos").document(doc_id)
        doc_snap = doc_ref.get()
        
        if doc_snap.exists:
            data = doc_snap.to_dict()
            if data.get("status") == "DONE":
                return True, data
        
        return False, None
    except Exception as e:
        logger.error(f"Error checking document: {e}")
        return False, None


def _persist_document_result(db: firestore.Client, folio_id: str, doc_id: str, file_id: str, 
                             gcs_uri: str, generation: str, classification: Dict[str, Any],
                             extraction: Dict[str, Any], status: str, error: Optional[Dict] = None) -> None:
    """Persiste resultado de documento con estructura jerárquica completa."""
    try:
        doc_ref = db.collection("folios").document(folio_id).collection("documentos").document(doc_id)
        
        doc_data = {
            "gcs_uri": gcs_uri,
            "generation": generation,
            "file_id": file_id,
            "status": status,
            "doc_type": classification.get("document_type", "UNKNOWN"),
            "classifier_confidence": classification.get("confidence", 0.0),
            "classifier_version": classification.get("classifier_version", ""),
            "updated_at": firestore.SERVER_TIMESTAMP,
        }
        
        if status == "DONE":
            doc_data["completed_at"] = firestore.SERVER_TIMESTAMP
        
        if error:
            doc_data["error_type"] = error.get("code", "")
            doc_data["error_message"] = error.get("message", "")
        
        doc_ref.set(doc_data, merge=True)
        
        # Guardar extracción en sub-colección
        if extraction and extraction.get("fields"):
            extraction_id = f"extraction-{_utc_iso()}"
            extraction_ref = doc_ref.collection("extracciones").document(extraction_id)
            extraction_ref.set({
                "fields": extraction.get("fields", {}),
                "metadata": extraction.get("metadata", {}),
                "created_at": firestore.SERVER_TIMESTAMP,
            })
        
        # Actualizar contadores del folio
        folio_ref = db.collection("folios").document(folio_id)
        folio_ref.update({
            "processed_docs": firestore.Increment(1),
            "last_update_at": firestore.SERVER_TIMESTAMP,
        })
        
    except Exception as e:
        logger.error(f"Error persisting document: {e}")


# ═══════════════════════════════════════════════════════════════════════════════
# DOCUMENT PROCESSING: Con procesamiento paralelo
# ═══════════════════════════════════════════════════════════════════════════════
def _process_single_document(folio_id: str, file_name: str, generation: str, bucket_name: str, 
                             db: firestore.Client) -> Dict[str, Any]:
    """Procesa un documento individual con manejo de errores y reintentos."""
    file_id = file_name.split("/")[-1]
    doc_id = _make_doc_id(folio_id, file_id, generation)
    gcs_uri = f"gs://{bucket_name}/{file_name}"
    
    try:
        # Verificar idempotencia
        already_processed, cached = _check_document_processed(db, folio_id, doc_id)
        if already_processed:
            logger.info(f"Document already processed (from cache): {file_id}")
            return {
                "file_name": file_name,
                "gcs_uri": gcs_uri,
                "status": "DONE",
                "from_cache": True,
                "doc_type": cached.get("doc_type", "UNKNOWN"),
            }
        
        # Validar PDF
        storage_client = storage.Client()
        is_valid, error_msg = _is_valid_pdf(file_name, storage_client, bucket_name)
        if not is_valid:
            raise AppError(
                code="INVALID_PDF",
                message=error_msg,
                stage="VALIDATION",
                details={"file": file_name}
            )
        
        # Clasificar
        logger.info(f"Classifying: {file_id}")
        classification = classify_document(gcs_uri)
        
        # Extraer
        logger.info(f"Extracting: {file_id}")
        extraction = extract_document_data(gcs_uri, classification["document_type"])
        
        # Persistir
        _persist_document_result(
            db, folio_id, doc_id, file_id, gcs_uri, generation,
            classification, extraction, "DONE"
        )
        
        return {
            "file_name": file_name,
            "gcs_uri": gcs_uri,
            "status": "DONE",
            "from_cache": False,
            "doc_type": classification["document_type"],
            "confidence": classification["confidence"],
        }
        
    except Exception as e:
        logger.error(f"Error processing {file_id}: {e}")
        
        # Persistir error
        _persist_document_result(
            db, folio_id, doc_id, file_id, gcs_uri, generation,
            {"document_type": "UNKNOWN", "confidence": 0.0},
            {}, "ERROR",
            error={"code": "PROCESSING_ERROR", "message": str(e)}
        )
        
        # Publicar a DLQ
        _publish_to_dlq(folio_id, gcs_uri, "PROCESSING_ERROR", str(e), MAX_RETRIES)
        
        return {
            "file_name": file_name,
            "gcs_uri": gcs_uri,
            "status": "ERROR",
            "error": str(e),
        }


def _process_documents_parallel(folio_id: str, documents: List[Tuple[str, str]], 
                                bucket_name: str, db: firestore.Client) -> List[Dict[str, Any]]:
    """Procesa múltiples documentos en paralelo con ThreadPoolExecutor."""
    results = []
    
    with ThreadPoolExecutor(max_workers=MAX_CONCURRENT_DOCS) as executor:
        # Submit all tasks
        future_to_doc = {
            executor.submit(_process_single_document, folio_id, file_name, generation, bucket_name, db): (file_name, generation)
            for file_name, generation in documents
        }
        
        # Collect results as they complete
        for future in as_completed(future_to_doc):
            file_name, generation = future_to_doc[future]
            try:
                result = future.result()
                results.append(result)
                logger.info(f"Completed: {file_name} - Status: {result['status']}")
            except Exception as e:
                logger.error(f"Failed to process {file_name}: {e}")
                results.append({
                    "file_name": file_name,
                    "status": "ERROR",
                    "error": str(e),
                })
    
    return results


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN ENTRY POINT: Eventarc handler
# ═══════════════════════════════════════════════════════════════════════════════
@functions_framework.cloud_event
def process_folder_on_ready(cloud_event):
    """
    Punto de entrada principal activado por Eventarc.
    
    Se activa cuando se crea un archivo 'is_ready' en GCS, lo que indica que
    una carpeta está lista para ser procesada completamente.
    """
    try:
        # Parse event data
        event_data = cloud_event.get_data()
        bucket_name = event_data.get("bucket", "")
        object_name = event_data.get("name", "")
        event_id = cloud_event.get("id", "")
        
        logger.info(f"Event received: {event_id} - Object: {object_name}")
        
        # Validar que es un archivo is_ready
        is_valid, folder_prefix = _is_ready_sentinel(object_name)
        if not is_valid:
            logger.info(f"Not an is_ready file, ignoring: {object_name}")
            return "OK - Not is_ready file", 200
        
        logger.info(f"Processing folder: {folder_prefix} in bucket: {bucket_name}")
        
        # Generar folio_id
        folio_id = _make_folio_id(bucket_name, folder_prefix)
        
        # Inicializar Firestore
        db = _get_firestore_client()
        _ensure_folio_document(db, folio_id, bucket_name, folder_prefix)
        
        # Log structured de inicio
        _json_log({
            "event_type": "folder_processing_start",
            "folio_id": folio_id,
            "bucket": bucket_name,
            "folder_prefix": folder_prefix,
            "event_id": event_id,
            "timestamp": _utc_iso(),
        })
        
        # Listar todos los PDFs en la carpeta
        documents = _list_pdfs_in_folder(bucket_name, folder_prefix)
        total_docs = len(documents)
        
        logger.info(f"Found {total_docs} PDF documents in folder")
        
        # Actualizar total_docs en Firestore
        db.collection("folios").document(folio_id).update({
            "total_docs": total_docs,
        })
        
        if total_docs == 0:
            logger.info("No documents to process")
            db.collection("folios").document(folio_id).update({
                "status": "DONE",
                "finished_at": firestore.SERVER_TIMESTAMP,
            })
            return "OK - No documents", 200
        
        # Procesar documentos en paralelo
        results = _process_documents_parallel(folio_id, documents, bucket_name, db)
        
        # Determinar estado final
        errors = [r for r in results if r.get("status") == "ERROR"]
        if errors:
            final_status = "DONE_WITH_ERRORS"
        else:
            final_status = "DONE"
        
        # Actualizar estado final del folio
        db.collection("folios").document(folio_id).update({
            "status": final_status,
            "finished_at": firestore.SERVER_TIMESTAMP,
        })
        
        # Log structured de finalización
        _json_log({
            "event_type": "folder_processing_complete",
            "folio_id": folio_id,
            "bucket": bucket_name,
            "folder_prefix": folder_prefix,
            "total_docs": total_docs,
            "successful": len([r for r in results if r.get("status") == "DONE"]),
            "errors": len(errors),
            "final_status": final_status,
            "timestamp": _utc_iso(),
        })
        
        logger.info(f"Folder processing complete - Status: {final_status}")
        return "OK", 200
        
    except Exception as e:
        logger.error(f"Fatal error processing folder: {e}")
        _json_log({
            "event_type": "folder_processing_error",
            "error": str(e),
            "timestamp": _utc_iso(),
        })
        return f"Error: {e}", 500
