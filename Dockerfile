# Usa imagen oficial de Python 3.11 slim para menor tamaño
FROM python:3.11-slim

# Establece variables de entorno para Python
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Crea directorio de trabajo
WORKDIR /app

# Copia archivos de dependencias primero (mejor cache de capas)
COPY requirements.txt .

# Instala dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Copia el código de la aplicación
COPY apolo_procesamiento_inteligente.py .

# Crea usuario no-root para seguridad
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

# Cambia a usuario no-root
USER appuser

# Expone puerto 8080 (estándar de Cloud Run)
EXPOSE 8080

# Configura el puerto desde variable de entorno
ENV PORT=8080

# Comando para iniciar la aplicación
CMD exec functions-framework \
    --target=document_processor \
    --source=apolo_procesamiento_inteligente.py \
    --signature-type=http \
    --port=$PORT
