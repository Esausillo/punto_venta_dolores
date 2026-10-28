# Punto de Venta Dolores

Punto de venta móvil hecho con **Flutter + SQLite local**, construido con **TDD** (primero la prueba, después el código). Funciona sin internet: guarda productos y ventas en una base de datos dentro del teléfono, calcula totales, IVA y cambio sin errores, descuenta el inventario automáticamente y hace el corte del día.

Proyecto del curso Desarrollo Móvil Integral · UTNG. Prof. Anastacio Rodríguez García.

## Capturas

| Catálogo | Carrito | Pago insuficiente | Cobro exitoso |
|:---:|:---:|:---:|:---:|
![Catálogo](docs/capturas/01_catalogo.png) | 
![Carrito](docs/capturas/02_carrito.png) | 
![Pago insuficiente](docs/capturas/03_pago_insuficiente.png) | 
![Cobro exitoso](docs/capturas/04_cobro_exitoso.png) |
| Lista de productos con existencias y precio. | Dos nieves de limón: total $50.00, IVA incluido $6.90. | Paga con $10: la app muestra el error sin cerrarse. | Paga con $100: cambio $50.00 y las existencias bajan de 40 a 38. |

### Cómo agregar tus capturas

1. Crea la carpeta `docs/capturas/` en la raíz del proyecto.
2. Corre la app con `flutter run`.
3. Reproduce cada pantalla y toma la captura:
   - **01_catalogo:** al abrir la app.
   - **02_carrito:** toca "Nieve de limón" dos veces.
   - **03_pago_insuficiente:** con el carrito anterior, escribe `10` en "Paga con $" y toca Cobrar.
   - **04_cobro_exitoso:** escribe `100` en "Paga con $" y toca Cobrar.
4. Guarda las imágenes en `docs/capturas/` con esos nombres exactos (`.png`).

## Características

- Catálogo de productos con búsqueda por nombre o código.
- Carrito que suma cantidades y valida existencias antes de agregar.
- IVA 16% incluido en el precio, desglosado con aritmética entera.
- Cálculo de cambio, con errores claros para pago insuficiente o carrito vacío.
- Cobro en una **transacción** de base de datos: o se guarda todo o no se guarda nada.
- Corte del día, productos más vendidos y alerta de bajo inventario.
- Datos de ejemplo (nevería de Dolores Hidalgo) en el primer arranque.

## Requisitos

- Flutter con Dart `>=3.0.0 <4.0.0`
- Un emulador o dispositivo para `flutter run`
- No se necesita emulador para las pruebas

## Instalación

```bash
flutter create punto_venta_dolores
cd punto_venta_dolores
mkdir lib/dominio lib/datos lib/presentacion
# copia pubspec.yaml, lib/ y test/ del proyecto
rm test/widget_test.dart
flutter pub get
```

## Uso

```bash
flutter test     # corre las 17 pruebas
flutter run      # abre la app
```

Prueba manual: toca "Nieve de limón" dos veces, escribe `100` en "Paga con $" y toca **Cobrar**. Debe aparecer "Cambio: $50.00" y las existencias bajan de 40 a 38.

Para reiniciar la base de datos de cero, desinstala la app del teléfono.

## Estructura del proyecto

```
punto_venta_dolores/
├── pubspec.yaml
├── docs/
│   └── capturas/                      imágenes del README
├── lib/
│   ├── main.dart                      composition root (conecta todo)
│   ├── dominio/                       reglas del negocio, Dart puro
│   │   ├── excepciones.dart
│   │   ├── dinero.dart
│   │   ├── producto.dart
│   │   ├── carrito.dart
│   │   └── venta.dart
│   ├── datos/                         SQLite
│   │   ├── base_datos.dart
│   │   ├── repositorio_productos.dart
│   │   └── repositorio_ventas.dart
│   └── presentacion/                  lo que ve el usuario
│       ├── caja_viewmodel.dart
│       └── pantalla_caja.dart
└── test/
    ├── dominio_test.dart              11 pruebas
    └── datos_test.dart                6 pruebas
```

## Arquitectura

Tres capas con dependencias en una sola dirección:

| Capa | Responsabilidad | Importa |
|---|---|---|
| `dominio` | Reglas de negocio puras | Nada de Flutter ni sqflite |
| `datos` | Persistencia en SQLite | `dominio` |
| `presentacion` | ViewModel y pantalla | `datos` y `dominio` |

`main.dart` es el único lugar donde se crean los objetos y se conectan entre sí.

### Decisiones de diseño

- **Dinero en centavos enteros.** Nunca `double`: `0.1 + 0.2` da `0.30000000000000004`. $25.00 se guarda como `2500` y solo se formatea al mostrarlo.
- **IVA por desglose.** Los precios ya incluyen IVA: `iva = total × 16 / 116`, redondeado con enteros. El subtotal se calcula como `total - iva`, así nunca falta ni sobra un centavo.
- **Excepciones de negocio.** Los errores técnicos de SQL se traducen a excepciones con nombre (por ejemplo `CodigoDuplicadoException`), para que el cajero nunca vea mensajes de SQL.
- **Transacción al cobrar.** Se revalidan las existencias dentro de la transacción y el inventario se descuenta con `existencias = existencias - ?`, no con leer, restar y guardar.
- **Líneas de venta con copia de nombre y precio.** Un ticket de hoy muestra lo que se cobró hoy, aunque mañana cambie el precio.
- **ViewModel.** La pantalla solo dibuja; el estado y la lógica de interacción viven en `CajaViewModel`.

## Pruebas

| Archivo | Qué cubre |
|---|---|
| `test/dominio_test.dart` | Formato y conversión de dinero, modelo `Producto`, carrito (cantidades, existencias, IVA, cambio, pago corto, carrito vacío) |
| `test/datos_test.dart` | Guardar y buscar, código duplicado, cobro que descuenta inventario, cobro fallido que no lo descuenta, corte del día, bajo inventario |

Las pruebas de datos usan una base **en memoria** con `sqflite_common_ffi`, así corren en tu computadora y cada prueba empieza con una base limpia.

### Ciclo TDD

1. 🔴 **Rojo:** escribe la prueba y comprueba que falla.
2. 🟢 **Verde:** escribe el código mínimo para que pase.
3. 🔵 **Refactor:** ordena nombres y estructura sin romper nada.

## Retos para ampliar el proyecto

- Pantalla de "Corte del día" con total, IVA, número de ventas y los 5 productos más vendidos.
- Pantalla de alta de productos con validación (precio mayor a cero, código único).
- Ticket de venta compartible como texto (paquete `share_plus`).
- Descuentos por porcentaje y por producto, con pruebas primero.
- Adaptar el sistema a otro negocio: papelería, taquería o tienda de Talavera.
- Prueba que venda las 5 existencias y luego intente vender una más.

## Dependencias

| Paquete | Uso |
|---|---|
| `sqflite` | SQLite en el teléfono |
| `path` | Ruta del archivo de base de datos |
| `sqflite_common_ffi` (dev) | SQLite en tu computadora para las pruebas |
| `flutter_lints` (dev) | Reglas de estilo |

---

*El código que no tiene prueba es un deseo, no una garantía.*