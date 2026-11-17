-- HotelDB | Comprobaciones de integridad y diagnóstico del dataset.
-- Ejecutar DESPUÉS de la migración. Las comprobaciones críticas lanzan THROW.
USE [BDHOTEL];
GO
SET NOCOUNT ON;
IF EXISTS (
    SELECT 1 FROM dbo.ESTANCIA
    WHERE Fecha_Salida <= Fecha_Entrada
)
    THROW 51100, 'Existen estancias con fechas invalidas.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.CLIENTE_HABITACION AS ch
    LEFT JOIN dbo.ESTANCIA AS e
      ON e.Id_Estancia = ch.Id_Estancia AND e.Id_Cliente = ch.Id_Cliente
    WHERE e.Id_Estancia IS NULL OR ch.Tarifa_Por_Noche <= 0
)
    THROW 51101, 'Existen asignaciones sin estancia o sin tarifa valida.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.CONSUMO AS co
    LEFT JOIN dbo.ESTANCIA AS e
      ON e.Id_Estancia = co.Id_Estancia AND e.Id_Cliente = co.Id_Cliente
    WHERE e.Id_Estancia IS NULL OR co.Cantidad <= 0
)
    THROW 51102, 'Existen consumos sin estancia o con cantidades invalidas.', 1;

IF EXISTS (
    SELECT 1
    FROM dbo.CLIENTE_HABITACION AS ch
    JOIN dbo.HABITACION AS h ON h.Id_Habitacion = ch.Id_Habitacion
    GROUP BY ch.Id_Estancia
    HAVING COUNT(DISTINCT h.Id_Hotel) > 1
)
    THROW 51103, 'Una estancia pertenece a varios hoteles.', 1;

SELECT 'CLIENTE' AS Tabla, COUNT_BIG(*) AS Filas FROM dbo.CLIENTE
UNION ALL SELECT 'ESTANCIA', COUNT_BIG(*) FROM dbo.ESTANCIA
UNION ALL SELECT 'HABITACION', COUNT_BIG(*) FROM dbo.HABITACION
UNION ALL SELECT 'CLIENTE_HABITACION', COUNT_BIG(*) FROM dbo.CLIENTE_HABITACION
UNION ALL SELECT 'CONSUMO', COUNT_BIG(*) FROM dbo.CONSUMO;

-- Solo diagnóstico: no declarar UNIQUE hasta decidir si los identificadores
-- repetidos representan la misma habitación física o datos sintéticos.
SELECT Id_Hotel, Numero_Habitacion, COUNT_BIG(*) AS Identificadores_Repetidos
FROM dbo.HABITACION
GROUP BY Id_Hotel, Numero_Habitacion
HAVING COUNT_BIG(*) > 1
ORDER BY Identificadores_Repetidos DESC, Id_Hotel, Numero_Habitacion;
GO
