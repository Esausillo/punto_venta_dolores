import 'package:sqflite/sqflite.dart';
import '../dominio/carrito.dart';
import '../dominio/excepciones.dart';
import '../dominio/venta.dart';

class RepositorioVentas {
  final Database db;
  RepositorioVentas(this.db);

  /// Cobra: valida pago, guarda venta + líneas y descuenta inventario.
  /// Todo en UNA transacción: o se guarda todo o no se guarda nada.
  Future<Venta> cobrar(Carrito carrito, int pagoCentavos, {DateTime? fecha}) async {
    carrito.cambio(pagoCentavos); // lanza si carrito vacío o pago corto
    final momento = fecha ?? DateTime.now();
    late int ventaId;
    await db.transaction((txn) async {
      // Revalida existencias contra la base (otro cajero pudo vender).
      for (final l in carrito.lineas) {
        final f = await txn.query('productos',
            columns: ['existencias'],
            where: 'codigo = ?',
            whereArgs: [l.producto.codigo]);
        final disp = f.isEmpty ? 0 : f.first['existencias'] as int;
        if (disp < l.cantidad) {
          throw ExistenciasInsuficientesException(l.producto.nombre, disp);
        }
      }
      ventaId = await txn.insert('ventas', {
        'fecha': momento.toIso8601String(),
        'total_centavos': carrito.totalCentavos,
        'iva_centavos': carrito.ivaCentavos,
        'pago_centavos': pagoCentavos,
      });
      for (final l in carrito.lineas) {
        await txn.insert('lineas_venta', {
          'venta_id': ventaId,
          'codigo': l.producto.codigo,
          'nombre': l.producto.nombre,
          'cantidad': l.cantidad,
          'precio_centavos': l.producto.precioCentavos,
        });
        await txn.rawUpdate(
            'UPDATE productos SET existencias = existencias - ? WHERE codigo = ?',
            [l.cantidad, l.producto.codigo]);
      }
    });
    return Venta(
      id: ventaId,
      fecha: momento,
      totalCentavos: carrito.totalCentavos,
      ivaCentavos: carrito.ivaCentavos,
      pagoCentavos: pagoCentavos,
      lineas: carrito.lineas
          .map((l) => LineaVenta(l.producto.codigo, l.producto.nombre,
              l.cantidad, l.producto.precioCentavos))
          .toList(),
    );
  }

  /// Corte del día: suma de ventas de la fecha dada.
  Future<ResumenDia> corteDelDia(DateTime dia) async {
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fin = inicio.add(const Duration(days: 1));
    final r = await db.rawQuery('''
      SELECT COUNT(*) AS n,
             COALESCE(SUM(total_centavos),0) AS total,
             COALESCE(SUM(iva_centavos),0) AS iva
      FROM ventas WHERE fecha >= ? AND fecha < ?''',
        [inicio.toIso8601String(), fin.toIso8601String()]);
    final f = r.first;
    return ResumenDia(f['n'] as int, f['total'] as int, f['iva'] as int);
  }

  /// Los más vendidos: ranking para decidir qué resurtir.
  Future<List<Map<String, Object?>>> masVendidos({int limite = 5}) =>
      db.rawQuery('''
        SELECT nombre, SUM(cantidad) AS unidades
        FROM lineas_venta GROUP BY codigo
        ORDER BY unidades DESC LIMIT ?''', [limite]);
}