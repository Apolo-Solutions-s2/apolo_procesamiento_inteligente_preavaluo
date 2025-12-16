# apolo\_procesamiento\_inteligente\_preavaluo

# Descripción del microservicio

Este microservicio pertenece al módulo de preavalúos Apolo y tiene como objetivo **ejecutar el procesamiento inteligente por carpeta** de documentos financieros previamente estandarizados a PDF/A.

Su razón de ser es, de forma **confiable, auditable, idempotente y paralela**:

1. Detectar automáticamente cuándo una carpeta de trabajo está lista para procesamiento (mediante un archivo bandera `is_ready` en el bucket).  
2. **Listar todos los documentos de la carpeta** y procesarlos:  
   * **Clasificación de documentos** (Document AI Classifier).  
   * **Extracción estructural** (Document AI Custom Extractor).  
3. **Persistir resultados con trazabilidad** en Firestore.  
4. **Registrar en Cloud Logging el avance por etapas** (recepción de carpeta, inicio de procesamiento, inicio de clasificación, inicio de extracción, fin de documento, fin de carpeta), de tal forma que **otra Cloud Function** pueda traducir estas señales a porcentajes de avance.  
5. Manejar fallas con reintentos controlados y, cuando aplique, DLQ y estados de error.

El microservicio es un **worker backend-only**, sin interfaz de usuario, se ejecuta sobre infraestructura **serverless en GCP**, y **no es un servicio en tiempo real**: se utilizará aproximadamente **una vez al mes** para procesar alrededor de **60 documentos** por corrida.

# Consideraciones funcionales

* El microservicio está diseñado para operar **por carpeta**, no por archivo individual en el punto de entrada.  
* Cada carpeta representa, típicamente, el conjunto de documentos financieros de un caso/folio de preavalúo.  
* Cuando una carpeta se marca como lista mediante el archivo `is_ready`, se asume que **no se subirán más archivos** a esa carpeta y se procede a procesar todos sus documentos.

# Activación por Eventarc y GCS

* La activación del microservicio se realiza mediante **Eventarc**, escuchando **eventos de Cloud Storage** del tipo “objeto finalizado” (`object finalize`).  
* **Condición de disparo (sentinel):**  
  * El evento debe corresponder a un objeto cuyo nombre cumpla con:  
    * Path del tipo:  
      `gs://{bucket}/{folder_prefix}/is_ready`  
    * El archivo `is_ready`:  
      * **No tiene extensión**.  
      * **No contiene contenido** (tamaño 0 bytes).  
  * Solo cuando se detecta el `is_ready` en una carpeta se considera que:  
    * Ya se han subido todos los documentos a esa carpeta.  
    * Es seguro iniciar el procesamiento inteligente completo.  
* **Derivación de carpeta:**  
  * A partir del evento de Eventarc:  
    * `bucket` se toma del propio evento de GCS.  
    * `folder_prefix` se obtiene del `object.name` sin el sufijo `/is_ready`.  
* **Entrega al menos una vez:**  
  * El diseño debe asumir que el evento `is_ready` puede entregarse múltiples veces y el microservicio debe ser **idempotente** respecto a la carpeta.

# Idempotencia y versionamiento

La idempotencia debe resolver dos escenarios:

1. **Re-entrega de eventos `is_ready` para la misma carpeta.**  
2. **Reprocesos o ejecuciones manuales para carpetas ya procesadas.**

Adicionalmente, se considera el caso de **nuevas carpetas que contienen documentos idénticos a otra carpeta ya procesada**.

## Dentro de una misma carpeta

* Se requiere garantizar que:  
  * La misma carpeta (`bucket + folder_prefix`) **no se procese de forma inconsistente** si se reciben múltiples eventos `is_ready`.  
  * Cada documento dentro de la carpeta **no se procese más de una vez por versión de objeto**, incluso si:  
    * Se vuelve a crear/eliminar el `is_ready`.  
    * Eventarc entrega el evento más de una vez.  
* **Mecanismos recomendados:**  
  * **Uso de `generation` de GCS:**  
    * Para cada documento se toma `gcs_uri` \+ `generation` como llave de idempotencia.  
    * Si existe ya en Firestore un registro con esa misma combinación en estado `DONE`, el documento no se reprocesa.  
  * **Registro de estado en Firestore:**  
    * Una colección por folio/carpeta que contenga:  
      * Estado global de la carpeta: `PENDING`, `PROCESSING`, `DONE`, `DONE_WITH_ERRORS`, `ERROR`.  
      * Estado por documento:  
        * `NOT_STARTED`, `IN_PROGRESS`, `DONE`, `ERROR`.  
        * Metadatos de versión (`generation`).  
  * **Protección ante reentradas:**  
    * Si se recibe un nuevo evento `is_ready` de una carpeta:  
      * Si la carpeta está en `DONE` o `DONE_WITH_ERRORS`, por defecto se ignora la re-ejecución (o se trata como reproceso explícito solo si se define una política para ello).  
      * Si está en `PROCESSING`, se evalúa el estado por documento y únicamente se reintentan los pendientes/erróneos, sin reprocesar lo ya `DONE`.  
      * Si está en `ERROR`, puede utilizarse como punto de re-proceso manual o controlado según políticas de operación.

## Carpeta nueva con documentos idénticos a otra carpeta ya procesada

* **Mejor práctica por simplicidad y claridad de negocio:**  
  * Cada carpeta representa un **caso lógico independiente** (por ejemplo, un nuevo ciclo mensual de preavalúo), por lo que:  
    * **Una nueva carpeta con documentos “idénticos” (mismo contenido) se trata como un nuevo lote de trabajo**.  
    * El microservicio **sí procesa** los documentos de la nueva carpeta, aunque su contenido sea igual al de una carpeta anterior.  
  * La idempotencia se garantiza **dentro de la misma carpeta y por versión de objeto**, no globalmente por contenido.  
* Si en el futuro se requiriera optimización de costo/tiempo mediante **deduplicación por hash de contenido**, ésta se gestionaría como una capa adicional:  
  * Almacenar un `content_hash` por documento.  
  * Reutilizar resultados de clasificación/extracción de otro documento con el mismo hash.  
  * Pero esta optimización es opcional y no se considera obligatoria en el alcance actual.

# Procesamiento paralelo

Aunque la ejecución se hace una vez al mes y el volumen esperado es de \~60 documentos, el procesamiento debe seguir **buenas prácticas de paralelismo** para maximizar robustez y tiempos razonables:

* **Paralelismo interno controlado:**  
  * Dentro de una ejecución del microservicio:  
    * Utilizar un **pool de workers** (tareas async / threads / procesos) para procesar múltiples documentos en paralelo.  
    * Definir un parámetro de configuración `MAX_CONCURRENT_DOCS` que limite el número de documentos procesados simultáneamente.  
    * El valor de `MAX_CONCURRENT_DOCS` puede ser moderado (por ejemplo, entre 4 y 10\) dado el volumen mensual (\~60 documentos), privilegiando estabilidad sobre throughput extremo.  
* **Concurrencia de Cloud Run:**  
  * Configurar la concurrencia de Cloud Run de forma acorde al patrón de ejecución:  
    * No se busca soporte para cientos de solicitudes simultáneas, sino un lote mensual.  
    * La configuración típica puede ser concurrencia **baja a media**, suficiente para atender eventuales reentradas de Eventarc sin saturar la instancia.  
* **Orden de trabajo:**  
  * Paso 1: listar todos los documentos de la carpeta (excluyendo `is_ready`).  
  * Paso 2: programar cada documento en el pool de workers.  
  * Cada worker:  
    * Valida idempotencia/estado.  
    * Ejecuta clasificación.  
    * Ejecuta extracción.  
    * Persiste resultados.  
    * Actualiza el estado del documento.

# Persistencia y trazabilidad (Firestore)

**Esquema lógico sugerido:**

* `folios/{folioId}`  
  (el `folioId` puede derivarse de `bucket + folder_prefix` o de alguna convención de negocio)  
  * `bucket`  
  * `folder_prefix`  
  * `status` (`PENDING`, `PROCESSING`, `DONE`, `DONE_WITH_ERRORS`, `ERROR`)  
  * `total_docs`  
  * `processed_docs`  
  * `created_at`, `started_at`, `finished_at`  
  * `last_update_at`  
  * Información de errores globales, si aplica.  
* `folios/{folioId}/documentos/{docId}`  
  * `gcs_uri`  
  * `generation`  
  * `status` (`NOT_STARTED`, `IN_PROGRESS`, `DONE`, `ERROR`)  
  * `doc_type` (clase del clasificador)  
  * `classifier_output_raw` (si se almacena)  
  * `extractor_output_summary` (resumen de lo extraído, si aplica)  
  * `error_type`, `error_message` (si aplica)  
  * `created_at`, `updated_at`  
* `folios/{folioId}/documentos/{docId}/extracciones/{extractionId}`  
  * Resultado raw del extractor (JSON estructurado):  
    * Campos de negocio:  
      * `LINE_ITEM_NAME`, `LINE_ITEM_VALUE`, `COLUMN_YEAR`  
      * `SECTION_HEADER`, `TOTAL_LABEL`  
      * `CURRENCY`, `UNITS_SCALE`, `REPORTING_PERIOD`  
      * `ORG_NAME`, `STATEMENT_TITLE`  
      * `TABLE_COLUMN_HEADER`, `TABLE_ROW_REF`, `TABLE_CELL_REF`  
    * Metadatos de trazabilidad:  
      * `page_refs` (número de página \+ bounding boxes)  
      * `text_spans` o “anchors” cuando existan  
      * `confidence`  
      * `processor_version`  
      * otros metadatos relevantes.

La prioridad es **poder reconstruir exactamente de dónde salió cada número** en el estado financiero, tanto a nivel de tabla como de posición en la página.

# Observabilidad y métricas

El microservicio debe exponer su comportamiento a través de **Cloud Logging con logs estructurados (JSON)**. Los logs son la **fuente primaria** para que otra Cloud Function derive porcentajes de avance u otros indicadores.

## Campos de contexto global

En los logs se recomienda incluir, como mínimo:

* `service_name` (por ejemplo, `apolo-procesamiento-inteligente`)  
* `bucket`  
* `folder_prefix`  
* `folio_id`  
* `eventarc_event_id`  
* `execution_id` o `request_id` (identificador interno de ejecución, si se usa)

## Campos por documento (en logs de evento por documento)

* `gcs_uri`  
* `generation`  
* `doc_status` (p. ej. `IN_PROGRESS`, `DONE`, `ERROR`)  
* `doc_type` (si ya se conoce)  
* `stage` contextual:  
  * `DOC_CLASSIFICATION_START`  
  * `DOC_CLASSIFICATION_DONE`  
  * `DOC_EXTRACTION_START`  
  * `DOC_EXTRACTION_DONE`  
  * `DOC_ERROR`  
* Campos de error en caso de fallas:  
  * `error_type`  
  * `error_message`

No se reporta `latency_ms` por documento como campo obligatorio; si en algún momento se desea medir latencia, puede inferirse a partir de timestamps o de métricas agregadas, pero no es un requerimiento de este diseño.

## Campos de progreso (a nivel carpeta)

* Logs específicos de progreso de carpeta pueden incluir:  
  * `total_docs`  
  * `processed_docs`  
  * `stage`:  
    * `INIT`  
    * `LISTING`  
    * `PROCESSING_START`  
    * `PROCESSING_IN_PROGRESS`  
    * `FINALIZING`  
    * `DONE`  
    * `DONE_WITH_ERRORS`  
    * `ERROR`

El **porcentaje de avance** no es responsabilidad de este microservicio:  
otra Cloud Function será la encargada de consumir estos logs (y, opcionalmente, el estado de Firestore) para calcular y exponer `progress_pct` a los consumidores que lo requieran.

## Métricas derivadas (para dashboards)

A partir de los logs (y Firestore) se pueden definir métricas agregadas, por ejemplo:

* Cantidad de carpetas procesadas por mes.  
* Latencia media por carpeta (inicio a fin, si se requiere).  
* Porcentaje de carpetas con `DONE` vs `DONE_WITH_ERRORS` vs `ERROR`.  
* Porcentaje de documentos que terminan en `DONE` vs `ERROR`.  
* Conteo de documentos reintentos.  
* Volumen de mensajes en DLQ (si se habilita).

# Manejo de fallas y DLQ

* **Reintentos internos:**  
  * Ante errores transitorios (por ejemplo, timeouts o fallas de Document AI, lecturas de GCS, llamadas a Firestore):  
    * Realizar reintentos con **backoff exponencial** y número máximo configurable.  
  * Registrar en logs:  
    * `error_type`  
    * `error_message`  
    * `attempt`  
* **Errores no recuperables (por documento):**  
  * Marcar el documento con `status = ERROR` en Firestore.  
  * Registrar el detalle en Firestore y en logs estructurados.  
* **Errores globales de carpeta:**  
  * Si un número significativo de documentos falla o se produce una falla crítica:  
    * Marcar el folio/carpeta en `DONE_WITH_ERRORS` o `ERROR`, según la política definida.  
    * Registrar el motivo en Firestore y logs.  
* **DLQ (opcional, recomendado):**  
  * Definir un tópico Pub/Sub de DLQ para:  
    * Carpetas que no se pudieron procesar correctamente.  
    * Documentos con fallas repetidas que requieran revisión manual.  
  * Payload mínimo:  
    * `bucket`, `folder_prefix`, `folio_id`  
    * `gcs_uri` (si aplica, cuando sea por documento)  
    * `error_type`, `error_message`  
    * `attempts`  
    * `timestamp`

# Seguridad

* El microservicio es **backend-only**, sin exposición directa a usuarios.  
* Se invoca únicamente a través de **Eventarc** usando una **service account dedicada** como identidad.  
* La service account del microservicio tiene **permisos mínimos** necesarios:  
  * Lectura (y, si aplica, listado) en el bucket de PDFs.  
  * Lectura/escritura en las colecciones de Firestore relevantes.  
  * Uso de Document AI.  
  * Publicación en Pub/Sub (para DLQ), si se habilita.  
* No se utilizan secretos externos:  
  * Toda autenticación se basa en **identidades de GCP (service accounts)** y permisos IAM.  
  * No se requiere Secret Manager para este microservicio.  
* No se configura un control de egress especial:  
  * El microservicio solo se comunica con servicios administrados de GCP (GCS, Firestore, Document AI, Pub/Sub, Logging).  
  * No se establece conexión con el exterior en ningún momento.

# Descripción técnica oficial del microservicio

* **Nombre lógico:** `apolo-procesamiento-inteligente-preavaluo`  
* **Tipo:** Microservicio backend-only en **Cloud Run** (service) protegido, activado por **Eventarc** en respuesta a eventos de Cloud Storage.  
* **Lenguaje:** Python 3.11  
* **Entrada:** Evento de Eventarc con información de GCS (`bucket`, `object.name`). Se procesa únicamente cuando el objeto corresponde a un archivo bandera `is_ready` válido.  
* **Salida principal:**  
  * Estado y resultados de procesamiento en Firestore.  
  * Logs estructurados que reflejan etapas de avance, estados de documentos y estados de carpeta.  
  * Opcionalmente, mensajes en un tópico DLQ de Pub/Sub para errores irrecuperables.  
* **Interacciones principales:**  
  * **Cloud Storage:** lectura de PDFs y metadatos.  
  * **Document AI:** clasificación y extracción estructural.  
  * **Firestore:** persistencia de estado y resultados.  
  * **Cloud Logging:** observabilidad, estados y errores.  
  * **Pub/Sub (opcional):** DLQ.  
* **Patrón de ejecución:**  
  * Lote mensual, \~60 documentos por corrida.  
  * Procesamiento paralelo controlado dentro de la carpeta.  
  * Idempotencia por carpeta y por documento (versión de objeto).

# Reporte Técnico del Microservicio

## Resumen Ejecutivo

El microservicio de Procesamiento Inteligente de preavalúos se encarga de orquestar, por carpeta, la clasificación y extracción estructural de documentos financieros PDF/A en el módulo Apolo. Es activado automáticamente cuando se detecta un archivo bandera `is_ready` en una carpeta del bucket, lo que indica que la carpeta está lista para ser procesada en su totalidad. A partir de ese momento, lista todos los documentos de la carpeta, los procesa en paralelo (clasificación y extracción mediante Document AI), persiste los resultados con trazabilidad detallada en Firestore y registra en Cloud Logging el avance por etapas y el estado de cada documento. El cálculo de porcentajes de avance es responsabilidad de otra Cloud Function que consume estos logs. El microservicio maneja fallas con reintentos, marca estados de error y puede integrar una DLQ para casos irrecuperables. No es un servicio en tiempo real; se ejecuta aproximadamente una vez al mes para procesar alrededor de 60 documentos.

## Arquitectura lógica (flujo)

1. **Evento de entrada (Eventarc):**  
   * Se recibe un evento de “objeto finalizado” de GCS.  
   * Se valida que:  
     * El objeto corresponde a `.../is_ready`.  
     * El archivo `is_ready` es de 0 bytes y sin extensión.  
   * Se extraen `bucket` y `folder_prefix`.  
   * Se registra en Firestore (o se actualiza) el folio/carpeta asociado y se marca como `PROCESSING`.  
2. **Listado de documentos:**  
   * Se listan todos los objetos en `gs://{bucket}/{folder_prefix}/`.  
   * Se excluye el archivo `is_ready`.  
   * Se filtran documentos válidos (por ejemplo, PDFs).  
   * Se calcula `total_docs` y se guarda en Firestore.  
3. **Inicialización de estado de documentos:**  
   * Para cada documento listado, se crea o actualiza un registro en `folios/{folioId}/documentos/{docId}` con:  
     * `status = NOT_STARTED`  
     * `gcs_uri`, `generation`  
   * Se registra en logs un evento de inicio de procesamiento de carpeta (`PROCESSING_START`).  
4. **Procesamiento paralelo de documentos:**  
   * Se crea un pool de workers internos (async/thread/proceso) con límite `MAX_CONCURRENT_DOCS`.  
   * Cada worker procesa un documento:  
     * Verifica idempotencia (`gcs_uri + generation`) y estado en Firestore.  
     * Marca el documento como `IN_PROGRESS`.  
     * Invoca Document AI Classifier y guarda el resultado (clase de documento y, si aplica, salida raw).  
     * Invoca Document AI Extractor según la clase y guarda los resultados raw y metadatos de trazabilidad en Firestore.  
     * Marca el documento como `DONE` o `ERROR` según el caso.  
     * Actualiza `processed_docs` a nivel folio y registra logs de etapa por documento.  
5. **Cierre de carpeta:**  
   * Una vez que todos los documentos están en estado terminal (`DONE` o `ERROR`):  
     * Si todos están `DONE`, la carpeta se marca como `DONE`.  
     * Si algunos están `ERROR`, la carpeta se marca como `DONE_WITH_ERRORS` o `ERROR`, según la política definida.  
   * Se registra un evento final en logs para la carpeta (`DONE` o `DONE_WITH_ERRORS`/`ERROR`).  
6. **DLQ (si se usa):**  
   * Si se definen políticas de DLQ, para carpetas o documentos con fallas irrecuperables se envía un mensaje a Pub/Sub con el contexto necesario para reprocesos o revisión manual.

## Observabilidad (SRE)

* Logs estructurados con:  
  * Contexto de Eventarc y GCS.  
  * Estados de documentos y carpetas.  
  * Etapas de procesamiento (inicio, clasificación, extracción, finalización, error).  
* Estos logs son consumidos por otra Cloud Function que:  
  * Interpreta las etapas y los campos `total_docs` / `processed_docs` (en Firestore y/o logs).  
  * Calcula el porcentaje de avance que se desee exponer a otras capas (UI, reportes, etc.).

## Seguridad

* El microservicio:  
  * Se ejecuta en Cloud Run.  
  * Es activado solo por Eventarc.  
  * Utiliza service accounts con permisos mínimos.  
  * No requiere gestión de secretos adicionales.  
  * No establece conexiones con sistemas externos fuera de GCP.

## Requerimientos a componentes previos y posteriores

* **Previos:**  
  * Un pipeline de ingestión que:  
    * Normalice documentos a PDF/A.  
    * Los suba a carpetas en el bucket bajo un esquema consistente.  
    * Cree el archivo `is_ready` vacío y sin extensión **solo cuando la carpeta esté completa**.  
* **Posteriores:**  
  * Servicios que:  
    * Consuman los resultados estructurados en Firestore para cálculo de indicadores, análisis financiero, generación de reportes, etc.  
    * Consuman logs (y eventualmente DLQ) para monitoreo, cálculo de porcentajes de avance y reprocesos o revisiones manuales.