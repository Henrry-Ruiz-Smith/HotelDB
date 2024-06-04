/*I. La vista debe mostrar Nombre del hotel, fecha Entrada/Salida, Modo de pago utilizado, Nombre completo de los clientes, Nivel de satisfacción, Tipo de Habitación y el precio de cada habitación.*/
CREATE VIEW vista_estancias AS
SELECT 
    ho.Nombre,
    m.Modo_Pago,
    CONCAT(c.Nombre,' ',c.Apellido) AS [Nombre de clientes],
    th.Tipo,
    th.Precio
FROM 
    ESTANCIA as e 
    JOIN MODO_PAGO m ON e.Id_Modo_Pago = m.Id_Modo_Pago  
    JOIN CLIENTE as c ON e.Id_Cliente = c.Id_Cliente 
    JOIN CLIENTE_HABITACION as ch ON e.Id_Cliente = ch.Id_Cliente 
    JOIN HABITACION as h ON ch.Id_Habitacion = h.Id_Habitacion 
    JOIN TIPO_HABITACION as th ON ch.Id_Habitacion = h.Id_Habitacion 
    JOIN HOTEL as ho ON h.Id_Tipo_Habitacion = th.Id_Tipo_Habitacion;

SELECT * FROM vista_estancias;

/*II. La vista debe mostrar Nombre del hotel, Nivel de satisfacción, cantidad de encuesta recibidas en el primer semestre del 2022*/

CREATE VIEW vista_satisfacion AS
SELECT
  ho.Nombre,
  s.Nivel_Satisfaccion,
  COUNT(ch.Id_Satisfaccion) AS [Total de encuestas]
FROM
  ESTANCIA AS e
  JOIN CLIENTE AS c ON e.Id_Cliente = c.Id_Cliente
  JOIN CLIENTE_HABITACION AS ch ON e.Id_Cliente = ch.Id_Cliente
  JOIN HABITACION AS h ON ch.Id_Habitacion = h.Id_Habitacion
  JOIN HOTEL AS ho ON h.Id_Hotel = ho.Id_Hotel
  JOIN SATISFACCION AS s ON ch.Id_Satisfaccion = s.Id_Satisfaccion
WHERE
  MONTH(e.Fecha_Entrada) IN (1, 2, 3, 4, 5, 6) AND
  s.Nivel_Satisfaccion IN ('Muy Satisfecho', 'Satisfecho', 'Neutral', 'Insatisfecho', 'Muy Insatisfecho')
GROUP BY
  ho.Nombre,
  s.Nivel_Satisfaccion;

SELECT * FROM vista_satisfacion;