-- CREACION BASE DE DATOS
CREATE DATABASE BDHOTEL
USE BDHOTEL

-- CREACION TABLAS
CREATE TABLE MODO_PAGO
(
Id_Modo_Pago INT PRIMARY KEY,
Modo_Pago VARCHAR(30) NOT NULL
)

CREATE TABLE TIPO_HABITACION
(
Id_Tipo_Habitacion INT PRIMARY KEY,
Tipo VARCHAR(30) NOT NULL,
Precio DECIMAL NOT NULL,
)

CREATE TABLE HOTEL
(
Id_Hotel INT PRIMARY KEY,
Nombre VARCHAR(30) NOT NULL,
Direccion VARCHAR(30) NOT NULL,
Ciudad Varchar(30) NOT NULL,
Telefono VARCHAR(30) NOT NULL,
)

CREATE TABLE TIPO_EMPLEADO
(
Id_Tipo_Empleado INT PRIMARY KEY,
Cargo VARCHAR(30) NOT NULL,
Salario DECIMAL NOT NULL
)

CREATE TABLE EMPLEADO
(
Id_Empleado INT PRIMARY KEY,
Nombre VARCHAR(30) NOT NULL,
Apellido VARCHAR(30) NOT NULL,
Edad VARCHAR(30) NOT NULL,
Sexo CHAR(30) NOT NULL,
Telefono VARCHAR(30) NOT NULL,
Ciudad VARCHAR(30) NOT NULL,
DNI VARCHAR(30) NOT NULL,
Turno VARCHAR(30) NOT NULL,
Id_Hotel INT,
Id_Tipo_Empleado INT ,
CONSTRAINT FK_Id_Hotel FOREIGN KEY (Id_Hotel) REFERENCES HOTEL(Id_Hotel),
CONSTRAINT FK_Id_Tipo_Empleado FOREIGN KEY (Id_Tipo_Empleado) REFERENCES TIPO_EMPLEADO (Id_Tipo_Empleado)
)

CREATE TABLE CLIENTE
(
Id_Cliente INT PRIMARY KEY,
Nombre VARCHAR(30) NOT NULL,
Apellido VARCHAR(30) NOT NULL,
FechaNac date NOT NULL,
Pais varchar(30) NOT NULL,
Telefono VARCHAR(30) NOT NULL,
DNI VARCHAR(30) NOT NULL,
Ciudad VARCHAR (30) NOT NULL,
)

CREATE TABLE ESTANCIA
(
Id_Estancia INT PRIMARY KEY,
Fecha_Entrada DATE NOT NULL,
Fecha_Salida DATE NOT NULL,
Id_Modo_Pago INT,
Id_Cliente INT,
CONSTRAINT FK_Id_Modo_Pago FOREIGN KEY(Id_Modo_Pago) REFERENCES  MODO_PAGO (Id_Modo_Pago), 
CONSTRAINT FK_Id_Cliente FOREIGN KEY(Id_Cliente) REFERENCES  CLIENTE (Id_Cliente)
)

CREATE TABLE HABITACION
(
Id_Habitacion INT PRIMARY KEY,
Numero_Habitacion VARCHAR(30) NOT NULL,
Id_Hotel INT,
Id_Tipo_Habitacion INT,
CONSTRAINT FK_Id_Hotel1 FOREIGN KEY (Id_Hotel) REFERENCES HOTEL (Id_Hotel),
CONSTRAINT FK_Id_Tipo_Habitacion FOREIGN KEY (Id_Tipo_Habitacion) REFERENCES TIPO_HABITACION (Id_Tipo_Habitacion)
)

CREATE TABLE SATISFACCION
(
Id_Satisfaccion INT PRIMARY KEY,
Nivel_Satisfaccion VARCHAR(30) NOT NULL,
)

CREATE TABLE TIPO_CONSUMIBLE
(
Id_Tipo_Consumible INT PRIMARY KEY,
Consumible VARCHAR(20)
)

CREATE TABLE CONSUMIBLE
(
Id_Consumible INT PRIMARY KEY,
Id_Tipo_Consumible INT FOREIGN KEY REFERENCES TIPO_CONSUMIBLE(Id_Tipo_Consumible),
Concepto VARCHAR(50) NOT NULL,
PrecioUnitario DECIMAL(10,2) NOT NULL
)

CREATE TABLE CONSUMO
(
Id_Consumo INT PRIMARY KEY,
Id_Consumible INT FOREIGN KEY REFERENCES CONSUMIBLE(Id_Consumible),
Cantidad INT NOT NULL,
Id_Cliente INT,
Constraint Fk_Id_Cliente1 Foreign key (Id_Cliente) REFERENCES Cliente(Id_Cliente)
)

CREATE TABLE CLIENTE_HABITACION
(
Id_Cliente_Habitacion INT PRIMARY KEY,
Id_Cliente INT,
Id_Habitacion INT,
Id_Satisfaccion int,
CONSTRAINT FK_Id_Satisfaccion FOREIGN KEY (Id_Satisfaccion) REFERENCES Satisfaccion(Id_Satisfaccion),
CONSTRAINT FK_Id_Cliente2  FOREIGN KEY (Id_Cliente) REFERENCES CLIENTE(Id_Cliente),
CONSTRAINT FK_Id_Habitacion  FOREIGN KEY (Id_Habitacion) REFERENCES HABITACION (Id_Habitacion)
)