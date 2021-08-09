-- Servidor2 - Secundário

USE master
GO
CREATE DATABASE TABD_TE2
GO
USE TABD_TE2 
GO
SET IMPLICIT_TRANSACTIONS OFF

-- Tabela distribuída entre os dois servidores
-- Pratos do dia com o nome entre A e M estão no server1
-- Pratos do dia com o nome entre N e Z ficam no server2
CREATE TABLE Prato_do_DiaNZ
(
      PratoID INT NOT NULL,
      Nome NVARCHAR(255) NOT NULL,
      Preco FLOAT NOT NULL,
      Descricao NVARCHAR(255) NOT NULL,
      Foto NVARCHAR(255) NOT NULL,
      Data NVARCHAR(255) NOT NULL,
      RestauranteID INT NOT NULL,
		PRIMARY KEY (PratoID, Nome),
		CHECK (Nome >= 'N')
)

--drop table  UtilizadorImpar

CREATE TABLE UtilizadorImpar
(
		UserID INT,
		Nome NVARCHAR(255) NOT NULL,               
		Email NVARCHAR(255) NOT NULL ,               
		Username NVARCHAR(255) NOT NULL ,            
		Password NVARCHAR(255) NOT NULL,            
		ValidarEmail BIT NOT NULL, 
		Estado BIT NOT NULL,
		Primary Key(UserID),
		--Primary Key (UserID, Username),
		CHECK (UserID%2=0)

)

-- Tabela existente só no server 2
CREATE TABLE Administrador 
(
		AdminID INT PRIMARY KEY
)

-- Tabela existente só no server 2
CREATE TABLE Bloquear_Utilizadores(
	
	UserID INT NOT NULL,
	AdminID INT REFERENCES Administrador (AdminID),
	Data_Bloqueio DATE NOT NULL,
	Motivo VARCHAR(MAX) NOT NULL,
	PRIMARY KEY(UserID, AdminID)
)
GO

--criar logins
CREATE LOGIN Cliente WITH PASSWORD= 'cliente'
CREATE LOGIN Restaurante WITH PASSWORD= 'restaurante'
CREATE LOGIN Administrador WITH PASSWORD= 'administrador'
CREATE LOGIN Convidado WITH PASSWORD= 'convidado'


--criar users
CREATE user Cliente_user for LOGIN Cliente
CREATE user Restaurante_user for LOGIN Restaurante
CREATE user Administrador_user for LOGIN Administrador
CREATE user Convidado_user for LOGIN Convidado

--permissoes do convidado
GRANT INSERT, SELECT ON UtilizadorImpar TO Convidado_user
GRANT SELECT ON Prato_do_DiaNZ TO Convidado_user


--permissoes do cliente
GRANT SELECT, UPDATE ON UtilizadorImpar TO Cliente_user
GRANT SELECT ON Prato_do_DiaNZ TO Cliente_user
GRANT SELECT ON Bloquear_Utilizadores TO Cliente_user
															

--permissoes do administrador
GRANT SELECT, INSERT, UPDATE, DELETE ON UtilizadorImpar TO Administrador_user
GRANT SELECT, UPDATE, INSERT ON Bloquear_Utilizadores TO Administrador_user
GRANT SELECT, INSERT, UPDATE ON Administrador TO Administrador_user


