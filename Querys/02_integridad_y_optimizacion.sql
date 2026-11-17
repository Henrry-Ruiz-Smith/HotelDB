-- HotelDB | Ejecutar DESPUÉS de lnsercion_Hotel.sql y ANTES de las vistas.
-- Reconciliación no destructiva de la muestra original (una estancia por cliente).
-- Para datos históricos con varias estancias por cliente hay que asignar
-- Id_Estancia explícitamente; el script se detiene si esa deducción es ambigua.
USE [BDHOTEL];
GO
SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'dbo.CLIENTE_HABITACION', N'Id_Estancia') IS NULL
    ALTER TABLE dbo.CLIENTE_HABITACION ADD Id_Estancia INT NULL;
IF COL_LENGTH(N'dbo.CONSUMO', N'Id_Estancia') IS NULL
    ALTER TABLE dbo.CONSUMO ADD Id_Estancia INT NULL;
IF COL_LENGTH(N'dbo.CLIENTE_HABITACION', N'Tarifa_Por_Noche') IS NULL
    ALTER TABLE dbo.CLIENTE_HABITACION ADD Tarifa_Por_Noche DECIMAL(12,2) NULL;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- No adivinar la estancia si hay cero o varias candidatas para un cliente.
    IF EXISTS (
        SELECT 1 FROM dbo.CLIENTE_HABITACION AS ch
        WHERE ch.Id_Estancia IS NULL
          AND (SELECT COUNT_BIG(*) FROM dbo.ESTANCIA AS e
               WHERE e.Id_Cliente = ch.Id_Cliente) <> 1
    )
        THROW 51000, 'Asignacion de habitacion ambigua: revise Id_Estancia.', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.CONSUMO AS co
        WHERE co.Id_Estancia IS NULL
          AND (SELECT COUNT_BIG(*) FROM dbo.ESTANCIA AS e
               WHERE e.Id_Cliente = co.Id_Cliente) <> 1
    )
        THROW 51001, 'Asignacion de consumo ambigua: revise Id_Estancia.', 1;

    UPDATE ch
       SET Id_Estancia = e.Id_Estancia
      FROM dbo.CLIENTE_HABITACION AS ch
      JOIN dbo.ESTANCIA AS e ON e.Id_Cliente = ch.Id_Cliente
     WHERE ch.Id_Estancia IS NULL;

    UPDATE co
       SET Id_Estancia = e.Id_Estancia
      FROM dbo.CONSUMO AS co
      JOIN dbo.ESTANCIA AS e ON e.Id_Cliente = co.Id_Cliente
     WHERE co.Id_Estancia IS NULL;

    -- Guardar la tarifa a nivel de asignacion para evitar recalcular ingresos
    -- historicos si se modifica el catalogo TIPO_HABITACION.Precio.
    UPDATE ch
       SET Tarifa_Por_Noche = th.Precio
      FROM dbo.CLIENTE_HABITACION AS ch
      JOIN dbo.HABITACION AS h ON h.Id_Habitacion = ch.Id_Habitacion
      JOIN dbo.TIPO_HABITACION AS th ON th.Id_Tipo_Habitacion = h.Id_Tipo_Habitacion
     WHERE ch.Tarifa_Por_Noche IS NULL;

    IF EXISTS (
        SELECT 1 FROM dbo.CLIENTE_HABITACION AS ch
        LEFT JOIN dbo.ESTANCIA AS e ON e.Id_Estancia = ch.Id_Estancia
        WHERE e.Id_Estancia IS NULL OR ch.Id_Cliente <> e.Id_Cliente
           OR ch.Tarifa_Por_Noche IS NULL OR ch.Tarifa_Por_Noche <= 0
    )
        THROW 51002, 'Asignaciones invalidas: estancia, cliente o tarifa.', 1;

    IF EXISTS (
        SELECT 1 FROM dbo.CONSUMO AS co
        LEFT JOIN dbo.ESTANCIA AS e ON e.Id_Estancia = co.Id_Estancia
        WHERE e.Id_Estancia IS NULL OR co.Id_Cliente <> e.Id_Cliente
    )
        THROW 51003, 'Consumos asociados a una estancia de otro cliente.', 1;

    -- El modelo analitico presupone que cada estancia pertenece a UN hotel.
    IF EXISTS (
        SELECT 1
        FROM dbo.CLIENTE_HABITACION AS ch
        JOIN dbo.HABITACION AS h ON h.Id_Habitacion = ch.Id_Habitacion
        GROUP BY ch.Id_Estancia
        HAVING COUNT(DISTINCT h.Id_Hotel) > 1
    )
        THROW 51004, 'Una estancia aparece asignada a hoteles distintos.', 1;

    IF EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.CLIENTE_HABITACION')
                 AND name = N'Id_Estancia' AND is_nullable = 1)
        ALTER TABLE dbo.CLIENTE_HABITACION ALTER COLUMN Id_Estancia INT NOT NULL;

    IF EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.CONSUMO')
                 AND name = N'Id_Estancia' AND is_nullable = 1)
        ALTER TABLE dbo.CONSUMO ALTER COLUMN Id_Estancia INT NOT NULL;

    IF EXISTS (SELECT 1 FROM sys.columns
               WHERE object_id = OBJECT_ID(N'dbo.CLIENTE_HABITACION')
                 AND name = N'Tarifa_Por_Noche' AND is_nullable = 1)
        ALTER TABLE dbo.CLIENTE_HABITACION ALTER COLUMN Tarifa_Por_Noche DECIMAL(12,2) NOT NULL;

    -- La FK compuesta garantiza la concordancia entre estancia y cliente.
    IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE name = N'UQ_ESTANCIA_CLIENTE')
        ALTER TABLE dbo.ESTANCIA
          ADD CONSTRAINT UQ_ESTANCIA_CLIENTE UNIQUE (Id_Estancia, Id_Cliente);

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CH_ESTANCIA_CLIENTE')
        ALTER TABLE dbo.CLIENTE_HABITACION WITH CHECK
          ADD CONSTRAINT FK_CH_ESTANCIA_CLIENTE FOREIGN KEY (Id_Estancia, Id_Cliente)
              REFERENCES dbo.ESTANCIA (Id_Estancia, Id_Cliente);

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_CONSUMO_ESTANCIA_CLIENTE')
        ALTER TABLE dbo.CONSUMO WITH CHECK
          ADD CONSTRAINT FK_CONSUMO_ESTANCIA_CLIENTE FOREIGN KEY (Id_Estancia, Id_Cliente)
              REFERENCES dbo.ESTANCIA (Id_Estancia, Id_Cliente);

    IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_CH_TARIFA')
        ALTER TABLE dbo.CLIENTE_HABITACION WITH CHECK
          ADD CONSTRAINT CK_CH_TARIFA CHECK (Tarifa_Por_Noche > 0);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.CLIENTE_HABITACION') AND name = N'IX_CH_ESTANCIA_HAB')
        CREATE INDEX IX_CH_ESTANCIA_HAB
          ON dbo.CLIENTE_HABITACION (Id_Estancia, Id_Habitacion)
          INCLUDE (Id_Satisfaccion, Tarifa_Por_Noche);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.HABITACION') AND name = N'IX_HAB_HOTEL_TIPO')
        CREATE INDEX IX_HAB_HOTEL_TIPO
          ON dbo.HABITACION (Id_Hotel, Id_Tipo_Habitacion)
          INCLUDE (Numero_Habitacion);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.ESTANCIA') AND name = N'IX_ESTANCIA_ENTRADA')
        CREATE INDEX IX_ESTANCIA_ENTRADA
          ON dbo.ESTANCIA (Fecha_Entrada)
          INCLUDE (Fecha_Salida, Id_Cliente, Id_Modo_Pago);

    IF NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE object_id = OBJECT_ID(N'dbo.CONSUMO') AND name = N'IX_CONSUMO_ESTANCIA_ITEM')
        CREATE INDEX IX_CONSUMO_ESTANCIA_ITEM
          ON dbo.CONSUMO (Id_Estancia, Id_Consumible)
          INCLUDE (Cantidad);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
