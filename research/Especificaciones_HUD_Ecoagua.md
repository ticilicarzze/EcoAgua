# Especificaciones de Diseño: HUD ECOAGUA
Documento de referencia basado en `UI KIT - HUD - ECOAGUA.pdf`.

## 1. Tipografía Base
* **Familia Tipográfica:** Cousine

### Títulos (Ej: "ZONA 1 - ESTADO EXCELENTE")
* **Caja:** Todo en mayúscula
* **Variable:** BOLD
* **Tamaño:** 12pt (mínimo)

### Etiquetas de Parámetros (Ej: Oxígeno Disuelto)
* **Caja:** Todo en minúscula (según especificación técnica)
* **Variable:** REGULAR
* **Tamaño:** 12pt (mínimo)

### Números y Valores (Ej: 8 mg/L)
* **Caja:** Todo en minúscula
* **Variable:** BOLD
* **Tamaño:** 12pt (mínimo)
* **Interletra:** -10% (específicamente entre los ceros y los puntos)

---

## 2. Parámetros del Contenedor (Fondo)
Aplicable a los paneles de todas las zonas:
* **Relleno (Color):** `#000000` (Negro)
* **Opacidad del Relleno:** 50%
* **Trazo (Grosor del borde):** 1.70pt
* **Radio de Esquina:** 10pt

---

## 3. Sistema de Colores por Zona
Códigos de color utilizados para los indicadores de estado y trazos de cada nivel:

* **ZONA 1 (Estado Excelente):** `#1AAC04`
* **ZONA 2:** `#D0D536`
* **ZONA 3:** `#EB7600`
* **ZONA 4:** `#FF0000`

---

## 4. Estructura de Datos (Ejemplo visualizado)
El panel muestra indicadores para los siguientes elementos con sus respectivos valores:
* **Oxígeno Disuelto:** 8 mg/L
* **Amonio:** 0.05 mg/L
* **Nitratos:** 1 mg/L
* **Fosfatos:** 0.05 mg/L
