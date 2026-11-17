-- HotelDB | Vistas compatibles con SQL Server 2019+.
-- Requiere ejecutar primero 02_integridad_y_optimizacion.sql.
USE [BDHOTEL];
GO

-- Granularidad: UNA FILA POR HABITACION ASIGNADA A CADA ESTANCIA.
-- Mantiene alias originales: Nombre, Modo_Pago, [Nombre de clientes], Tipo, Precio.
CREATE OR ALTER VIEW dbo.vista_estancias
AS
SELECT
    e.Id_Estancia,
    e.Id_Cliente,
    e.Fecha_Entrada,
    e.Fecha_Salida,
    DATEDIFF(DAY, e.Fecha_Entrada, e.Fecha_Salida) AS Noches,
    e.Id_Modo_Pago,
    mp.Modo_Pago,
    h.Id_Hotel,
    ho.Nombre,
    h.Id_Habitacion,
    h.Numero_Habitacion,
    th.Id_Tipo_Habitacion,
    th.Tipo,
    ch.Tarifa_Por_Noche AS Precio,
    ch.Tarifa_Por_Noche,
    CAST(DATEDIFF(DAY, e.Fecha_Entrada, e.Fecha_Salida) * ch.Tarifa_Por_Noche AS DECIMAL(18,2)) AS Ingreso_Alojamiento,
    s.Nivel_Satisfaccion,
    CONCAT(c.Nombre, ' ', c.Apellido) AS [Nombre de clientes]
FROM dbo.CLIENTE_HABITACION AS ch
JOIN dbo.ESTANCIA AS e
  ON e.Id_Estancia = ch.Id_Estancia AND e.Id_Cliente = ch.Id_Cliente
JOIN dbo.CLIENTE AS c ON c.Id_Cliente = e.Id_Cliente
JOIN dbo.HABITACION AS h ON h.Id_Habitacion = ch.Id_Habitacion
JOIN dbo.HOTEL AS ho ON ho.Id_Hotel = h.Id_Hotel
JOIN dbo.TIPO_HABITACION AS th ON th.Id_Tipo_Habitacion = h.Id_Tipo_Habitacion
JOIN dbo.MODO_PAGO AS mp ON mp.Id_Modo_Pago = e.Id_Modo_Pago
LEFT JOIN dbo.SATISFACCION AS s ON s.Id_Satisfaccion = ch.Id_Satisfaccion;
GO

-- Encuestas en estancias iniciadas en el PRIMER SEMESTRE DE 2022.
-- No existe fecha real de encuesta: la fecha de entrada es el proxy documentado.
-- Nombre de vista original conservado para compatibilidad.
CREATE OR ALTER VIEW dbo.vista_satisfacion
AS
SELECT
    h.Id_Hotel,
    ho.Nombre,
    s.Nivel_Satisfaccion,
    COUNT_BIG(*) AS [Total de encuestas]
FROM dbo.CLIENTE_HABITACION AS ch
JOIN dbo.ESTANCIA AS e
  ON e.Id_Estancia = ch.Id_Estancia AND e.Id_Cliente = ch.Id_Cliente
JOIN dbo.HABITACION AS h ON h.Id_Habitacion = ch.Id_Habitacion
JOIN dbo.HOTEL AS ho ON ho.Id_Hotel = h.Id_Hotel
JOIN dbo.SATISFACCION AS s ON s.Id_Satisfaccion = ch.Id_Satisfaccion
WHERE e.Fecha_Entrada >= '20220101'
  AND e.Fecha_Entrada < '20220701'
GROUP BY h.Id_Hotel, ho.Nombre, s.Nivel_Satisfaccion;
GO
