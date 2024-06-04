/*1.- En el hotel con menos ingresos. ¿Cuál es el consumible que más se demanda? ¿Qué porcentaje del total representa el tipo de consumible (agrupación)?*/

SELECT 
tc.Consumible, 
SUM(c.Cantidad * co.PrecioUnitario) as IngresoConsumibles,
COUNT(c.Cantidad) as Demanda
FROM CONSUMO c
JOIN CLIENTE_HABITACION ch ON c.id_cliente = ch.id_cliente
JOIN HABITACION ha ON ch.id_habitacion = ha.id_habitacion
JOIN CONSUMIBLE co ON c.id_consumible = co.id_consumible
JOIN TIPO_CONSUMIBLE tc ON co.id_tipo_consumible = tc.id_tipo_consumible
WHERE ha.id_hotel = (
    SELECT TOP 1 h.id_hotel
    FROM HOTEL h
    JOIN Habitacion ha ON ha.id_hotel = h.id_hotel
    JOIN Tipo_Habitacion th ON th.id_tipo_habitacion = ha.id_tipo_habitacion
    JOIN Cliente_Habitacion ch ON ch.id_habitacion = ha.id_habitacion
    JOIN Estancia e ON e.id_cliente = ch.id_cliente
    GROUP BY h.id_hotel
    ORDER BY SUM(DATEDIFF(day, e.fecha_entrada, e.fecha_salida) * th.precio) ASC
)
GROUP BY tc.Consumible
ORDER BY IngresoConsumibles DESC

/*2. ¿Qué habitación tiene el mayor nivel de satisfacción de los clientes, en cada uno de los hoteles?*/

SELECT
    ho.Nombre,
    th.Tipo,
    COUNT(ch.Id_Satisfaccion) [Clientes muy Satisfechos]
FROM 
    ESTANCIA as e 
    JOIN CLIENTE as c ON e.Id_Cliente = c.Id_Cliente 
    JOIN CLIENTE_HABITACION as ch ON e.Id_Cliente = ch.Id_Cliente 
    JOIN HABITACION as h ON ch.Id_Habitacion = h.Id_Habitacion 
    JOIN HOTEL as ho ON h.Id_Hotel = ho.Id_Hotel 
    JOIN TIPO_HABITACION as th ON h.Id_Tipo_Habitacion = th.Id_Tipo_Habitacion 
    JOIN SATISFACCION as s ON ch.Id_Satisfaccion = s.Id_Satisfaccion
WHERE 
    s.Nivel_Satisfaccion = 'Muy Satisfecho'
GROUP BY 
    ho.Nombre, th.Tipo
ORDER BY 
    COUNT(ch.Id_Satisfaccion) desc

/*3. ¿Qué tipo de pago es el que más prefieren los clientes, en cada uno de los hoteles?*/

WITH CTE AS (
  SELECT
    ho.Nombre,
    m.Modo_Pago,
    COUNT(e.Id_Estancia) AS [Cantidad de veces que se uso],
    ROW_NUMBER() OVER (PARTITION BY ho.Nombre ORDER BY COUNT(e.Id_Estancia) DESC) AS RowNum
  FROM ESTANCIA AS e
  JOIN CLIENTE AS c ON e.Id_Cliente = c.Id_Cliente
  JOIN CLIENTE_HABITACION AS ch ON e.Id_Cliente = ch.Id_Cliente
  JOIN HABITACION AS h ON ch.Id_Habitacion = h.Id_Habitacion
  JOIN HOTEL AS ho ON h.Id_Hotel = ho.Id_Hotel
  JOIN MODO_PAGO AS m ON e.Id_Modo_Pago = m.Id_Modo_Pago
  GROUP BY ho.Nombre, m.Modo_Pago
)
SELECT Nombre, Modo_Pago, [Cantidad de veces que se uso]
FROM CTE
WHERE RowNum = 1
ORDER BY Nombre;

/*4. ¿Qué hotel tiene un mayor nivel de satisfacción por parte de los clientes en el último trimestre del 2022?*/

SELECT
  ho.Nombre,
  s.Nivel_Satisfaccion,
  COUNT(ch.Id_Satisfaccion) AS [Cantidad de veces que se uso]
FROM
  ESTANCIA AS e
  JOIN CLIENTE AS c ON e.Id_Cliente = c.Id_Cliente
  JOIN CLIENTE_HABITACION AS ch ON e.Id_Cliente = ch.Id_Cliente
  JOIN HABITACION AS h ON ch.Id_Habitacion = h.Id_Habitacion
  JOIN HOTEL AS ho ON h.Id_Hotel = ho.Id_Hotel
  JOIN SATISFACCION AS s ON ch.Id_Satisfaccion = s.Id_Satisfaccion
WHERE
  MONTH(e.Fecha_Entrada) IN (10, 11, 12) AND
  s.Nivel_Satisfaccion IN ('Muy Satisfecho', 'Satisfecho')
GROUP BY
  ho.Nombre,
  s.Nivel_Satisfaccion
ORDER BY
  s.Nivel_Satisfaccion,
  COUNT(ch.Id_Satisfaccion) DESC;

/*5. ¿Qué tipo de habitación genera mayores ingresos al año, en cada hotel?*/
WITH CTE AS (
  SELECT
    ho.Nombre,
    th.Tipo,
    SUM(DATEDIFF(day, e.Fecha_Entrada, e.Fecha_Salida) * th.Precio) AS [Ingresos],
    ROW_NUMBER() OVER (PARTITION BY ho.Nombre ORDER BY SUM(DATEDIFF(day, e.Fecha_Entrada, e.Fecha_Salida) * th.Precio) DESC) AS RN
  FROM
    ESTANCIA AS e
    JOIN CLIENTE AS c ON e.Id_Cliente = c.Id_Cliente
    JOIN CLIENTE_HABITACION AS ch ON e.Id_Cliente = ch.Id_Cliente
    JOIN HABITACION AS h ON ch.Id_Habitacion = h.Id_Habitacion
    JOIN HOTEL AS ho ON h.Id_Hotel = ho.Id_Hotel
    JOIN TIPO_HABITACION AS th ON h.Id_Tipo_Habitacion = th.Id_Tipo_Habitacion
  GROUP BY
    ho.Nombre,
    th.Tipo
)
SELECT Nombre, Tipo, Ingresos
FROM CTE
WHERE RN = 1
ORDER BY Ingresos DESC;
