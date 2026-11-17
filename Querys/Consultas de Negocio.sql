-- HotelDB | Cinco preguntas de negocio con granularidad correcta.
-- Requisitos: Creacion_Hotel -> lnsercion_Hotel -> 02_integridad_y_optimizacion -> Vistas.
USE [BDHOTEL];
GO

-- 1) Hotel con menor ingreso por alojamiento (en toda la muestra):
--    consumo por TIPO, unidades demandadas, ingreso y porcentaje de unidades.
--    La agrupación DISTINCT estancia/hotel impide duplicar consumos cuando una
--    estancia contiene varias habitaciones del mismo hotel.
;WITH IngresosHotel AS (
    SELECT Id_Hotel, MAX(Nombre) AS Hotel,
           SUM(Ingreso_Alojamiento) AS Ingresos_Alojamiento
    FROM dbo.vista_estancias
    GROUP BY Id_Hotel
), HotelMenorIngreso AS (
    SELECT TOP (1) Id_Hotel, Hotel, Ingresos_Alojamiento
    FROM IngresosHotel
    ORDER BY Ingresos_Alojamiento ASC, Id_Hotel ASC
), EstanciaHotel AS (
    SELECT DISTINCT ch.Id_Estancia, h.Id_Hotel
    FROM dbo.CLIENTE_HABITACION AS ch
    JOIN dbo.HABITACION AS h ON h.Id_Habitacion = ch.Id_Habitacion
), DemandaTipo AS (
    SELECT eh.Id_Hotel, tc.Consumible AS Tipo_Consumible,
           SUM(co.Cantidad) AS Unidades_Demandadas,
           SUM(CAST(co.Cantidad * i.PrecioUnitario AS DECIMAL(18,2))) AS Ingresos_Consumibles
    FROM dbo.CONSUMO AS co
    JOIN EstanciaHotel AS eh ON eh.Id_Estancia = co.Id_Estancia
    JOIN dbo.CONSUMIBLE AS i ON i.Id_Consumible = co.Id_Consumible
    JOIN dbo.TIPO_CONSUMIBLE AS tc ON tc.Id_Tipo_Consumible = i.Id_Tipo_Consumible
    GROUP BY eh.Id_Hotel, tc.Consumible
)
SELECT hm.Hotel, hm.Ingresos_Alojamiento, d.Tipo_Consumible,
       d.Unidades_Demandadas, d.Ingresos_Consumibles,
       CAST(100.0 * d.Unidades_Demandadas /
            NULLIF(SUM(d.Unidades_Demandadas) OVER (), 0) AS DECIMAL(7,2)) AS Porcentaje_Unidades
FROM HotelMenorIngreso AS hm
JOIN DemandaTipo AS d ON d.Id_Hotel = hm.Id_Hotel
ORDER BY d.Unidades_Demandadas DESC, d.Tipo_Consumible;
GO

-- 2) Tipo de habitación mejor valorado EN CADA HOTEL:
--    porcentaje de respuestas "Muy satisfecho" sobre encuestas respondidas.
--    Comparar porcentajes evita que el tipo más vendido gane por volumen.
;WITH Encuestas AS (
    SELECT v.Id_Hotel, v.Nombre AS Hotel, v.Tipo,
           COUNT_BIG(*) AS Total_Encuestas,
           SUM(CASE WHEN v.Nivel_Satisfaccion = 'Muy satisfecho' THEN 1 ELSE 0 END) AS Muy_Satisfechos
    FROM dbo.vista_estancias AS v
    WHERE v.Nivel_Satisfaccion IS NOT NULL
    GROUP BY v.Id_Hotel, v.Nombre, v.Tipo
), Ranking AS (
    SELECT *,
           CAST(100.0 * Muy_Satisfechos / NULLIF(Total_Encuestas, 0) AS DECIMAL(7,2)) AS Porcentaje_Muy_Satisfechos,
           DENSE_RANK() OVER (
               PARTITION BY Id_Hotel
               ORDER BY 1.0 * Muy_Satisfechos / NULLIF(Total_Encuestas, 0) DESC
           ) AS Posicion
    FROM Encuestas
)
SELECT Hotel, Tipo, Total_Encuestas, Muy_Satisfechos, Porcentaje_Muy_Satisfechos
FROM Ranking
WHERE Posicion = 1
ORDER BY Hotel, Tipo;
GO

-- 3) Medio de pago más utilizado en cada hotel. Una estancia se cuenta UNA vez;
--    DENSE_RANK muestra los empates en primer lugar.
;WITH EstanciasHotel AS (
    SELECT DISTINCT v.Id_Estancia, v.Id_Hotel, v.Nombre AS Hotel, v.Id_Modo_Pago, v.Modo_Pago
    FROM dbo.vista_estancias AS v
), Frecuencia AS (
    SELECT Id_Hotel, Hotel, Id_Modo_Pago, Modo_Pago,
           COUNT_BIG(*) AS Veces_Utilizado
    FROM EstanciasHotel
    GROUP BY Id_Hotel, Hotel, Id_Modo_Pago, Modo_Pago
), Ranking AS (
    SELECT *, DENSE_RANK() OVER (
        PARTITION BY Id_Hotel ORDER BY Veces_Utilizado DESC
    ) AS Posicion
    FROM Frecuencia
)
SELECT Hotel, Modo_Pago, Veces_Utilizado
FROM Ranking
WHERE Posicion = 1
ORDER BY Hotel, Modo_Pago;
GO

-- 4) Hotel con mayor SATISFACCIÓN FAVORABLE (Satisfecho + Muy satisfecho)
--    para estancias iniciadas entre el 01-oct y el 31-dic de 2022.
;WITH Encuestas AS (
    SELECT v.Id_Hotel, v.Nombre AS Hotel,
           COUNT_BIG(*) AS Encuestas,
           SUM(CASE WHEN v.Nivel_Satisfaccion IN ('Satisfecho', 'Muy satisfecho')
                    THEN 1 ELSE 0 END) AS Favorables
    FROM dbo.vista_estancias AS v
    WHERE v.Fecha_Entrada >= '20221001' AND v.Fecha_Entrada < '20230101'
      AND v.Nivel_Satisfaccion IS NOT NULL
    GROUP BY v.Id_Hotel, v.Nombre
), Ranking AS (
    SELECT *,
           CAST(100.0 * Favorables / NULLIF(Encuestas, 0) AS DECIMAL(7,2)) AS Porcentaje_Favorable,
           DENSE_RANK() OVER (
               ORDER BY 1.0 * Favorables / NULLIF(Encuestas, 0) DESC
           ) AS Posicion
    FROM Encuestas
)
SELECT Hotel, Encuestas, Favorables, Porcentaje_Favorable
FROM Ranking
WHERE Posicion = 1
ORDER BY Hotel;
GO

-- 5) Tipo de habitación que más ingresos de alojamiento genera POR HOTEL Y AÑO.
--    Se imputa el importe al año de entrada; para estancias entre dos años
--    haría falta prorratear las noches por año calendario.
;WITH Ingresos AS (
    SELECT v.Id_Hotel, v.Nombre AS Hotel, YEAR(v.Fecha_Entrada) AS Anio, v.Tipo,
           SUM(v.Ingreso_Alojamiento) AS Ingresos_Alojamiento
    FROM dbo.vista_estancias AS v
    GROUP BY v.Id_Hotel, v.Nombre, YEAR(v.Fecha_Entrada), v.Tipo
), Ranking AS (
    SELECT *, DENSE_RANK() OVER (
        PARTITION BY Id_Hotel, Anio ORDER BY Ingresos_Alojamiento DESC
    ) AS Posicion
    FROM Ingresos
)
SELECT Hotel, Anio, Tipo, Ingresos_Alojamiento
FROM Ranking
WHERE Posicion = 1
ORDER BY Anio, Hotel, Tipo;
GO
