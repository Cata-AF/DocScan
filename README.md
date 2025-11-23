# DocScan (docx integrity checker)

Herramienta Godot 4.5 para validar reportes DOCX. Descarga Pandoc y LibreOffice portables, convierte los .docx a XHTML/XML y genera comentarios de integridad (KPI LTE/UMTS, imagenes rotas, conteo de figuras/tablas) listos para revisar en la interfaz.

## Uso rapido
- Abrir el proyecto en Godot 4.5 (`res://main.tscn`).
- Si el panel de dependencias esta visible, pulsar **Download** para obtener Pandoc 3.8.2 y LibreOffice portable 25.2.3 (requiere red; en Windows tambien se necesita `C:\Program Files\7-Zip\7z.exe`).
- Arrastrar uno o varios `.docx` a la ventana; se listan en el panel izquierdo.
- Pulsar **Process files**: se generan `.xhtml` y `.xml` en `temp/` y aparecen tarjetas plegables en el panel derecho.
- Pulsar **Analize files** (o abrir cada tarjeta) para ver los comentarios de integridad y abrir el HTML en el navegador.

## Flujo general
```mermaid
flowchart LR
    U[Usuario arrastra .docx] --> M[ICMain.gd]
    M -->|Descarga/valida| D[bin/Pandoc + LibreOffice]
    M -->|Convierte| C[DOCX -> XHTML + XML en temp/]
    C --> P[ICProcessedFile.gd]
    P -->|Analiza| R[Comentarios (KPI, imagenes, figuras)]
    P -->|Abre| N[Navegador con XHTML]
```

## Estructura del proyecto
- `main.tscn`: escena principal con panel de dependencias, lista de entrada y contenedor de resultados.
- `scenes/processed_file.tscn`: tarjeta plegable por archivo procesado.
- `scripts/ICMain.gd`: orquestador de dependencias, arrastre y conversion.
- `scripts/ICProcessedFile.gd`: analisis y comentarios por archivo convertido.
- `bin/`: descargas portables (creado en ejecucion). `temp/`: salidas XHTML/XML (limpiado al inicio fuera del editor).

## Scripts .gd
### ICMain.gd
- Gestiona rutas de trabajo (`bin/`, `temp/`) y valida dependencias (`get_pandoc_path`, `get_libreoffice_path`, aviso de 7zip en Windows).
- Descarga automatica: usa `HTTPRequest` para traer Pandoc/LibreOffice; en Linux extrae con `tar`, en Windows con `Expand-Archive` y 7zip para el instalador portable.
- Manejo de arrastre: `_on_window_files_dropped` filtra `.docx`, los muestra y enfoca la ventana.
- Procesamiento: `_on_button_process_pressed` limpia resultados previos, crea el `temp/`, instancia `ICProcessedFile` y lanza `process_file` (opcionalmente en hilos si se habilita `use_threads`).
- Conversion por archivo (`process_file`): usa LibreOffice headless para XHTML y Pandoc para XML, normaliza nombres con espacios y crea la tarjeta de resultados. En Linux existe un modo `simulate_windows_on_linux` para usar Wine.
- Sincronizacion: `on_finish_process_file` actualiza barras de progreso y añade la tarjeta; `_on_close_requested` espera hilos activos.

### ICProcessedFile.gd
- `setup`: asocia las rutas generadas y titula la tarjeta.
- `validate_integrity`: selecciona validacion LTE o UMTS segun el nombre del archivo.
- Reglas LTE: revisa KPI (`CLUSTER RSRP Average`, `CLUSTER SINR Average`, `VoLTE Call Drop Rate`, `IntraFreq HO`) diferenciando bandas High/Low y promedia valores de cluster.
- Reglas UMTS: revisa KPI (`RSCP avg`, `EcIo avg`, `SC WCDMA Call Drop Rate`, `SHO Success Rate`), detecta valores faltantes o degradados.
- `set_commentaries`: vuelca comentarios en el TextEdit y los inyecta en el XHTML bajo un bloque "Integrity Check Comments".
- `verify_broken_images`: detecta imagenes corruptas (por patron base64) y las reemplaza por un marcador rojo, anotando la cantidad en comentarios.
- `summarize_media_counts_by_category`: recorre el XHTML, cuenta figuras/tablas/imagenes por seccion (LTE/UMTS) y reporta diferencias entre figuras declaradas y medios presentes.
- Utilidades: `get_file_type` infiere LTE/UMTS desde el nombre; `_on_button_open_in_browser_pressed` abre el XHTML en el navegador.

## Dependencias y rutas
- Godot 4.5 (feature flag en `project.godot`).
- Descargas en tiempo de ejecucion: Pandoc 3.8.2 y LibreOffice portable 25.2.3 hacia `bin/`; salidas en `temp/`.
- Windows requiere 7zip en `C:\Program Files\7-Zip\7z.exe` para extraer el instalador portable de LibreOffice.
- En el editor se limpia `temp/` al arrancar si existe y no se esta dentro del editor (evita residuos en builds exportados).

## Notas de desarrollo
- El flag `use_threads` esta deshabilitado por defecto; al activarlo crea un hilo por archivo y actualiza progreso via `call_deferred`.
- `simulate_windows_on_linux` permite probar el flujo Windows desde Linux usando Wine para rutas DOCX y LibreOffice.
- Los archivos HTML inyectan comentarios y marcadores de imagen rota; no se sobreescribe el DOCX original.

## Exportar o probar
- Escena principal: `main.tscn`.
- Para builds fuera del editor confirmar conectividad para descargas la primera vez; las dependencias quedan cacheadas en `bin/`.
