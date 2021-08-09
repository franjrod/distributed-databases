-- Servidor1 - Principal

EXEC sp_addlinkedserver @server = 'server2',
   @srvproduct = 'SQLServer Native Client OLEDB Provider',
   @provider = 'SQLNCLI',
   @datasrc = '25.62.240.207' 

EXEC sp_addlinkedsrvlogin @rmtsrvname = 'server2',
   @useself = 'FALSE',
   @locallogin = 'sa',
   @rmtuser = 'sa',
   @rmtpassword = '12345'

USE MASTER 
GO
CREATE DATABASE TABD_TE2
GO
USE TABD_TE2
GO
SET IMPLICIT_TRANSACTIONS OFF

CREATE TABLE UtilizadorPar
(
		UserID INT,
		Nome NVARCHAR(255) NOT NULL,               
		Email NVARCHAR(255) NOT NULL ,               
		Username NVARCHAR(255) NOT NULL,            
		Password NVARCHAR(255) NOT NULL,            
		ValidarEmail BIT NOT NULL, 
		Estado BIT NOT NULL,
		PRIMARY KEY (UserID),
		CHECK (UserID%2 <1)
)
CREATE TABLE Restaurante
(
		RestauranteID INT PRIMARY KEY,
		Fotos NVARCHAR(255) NOT NULL,
		Horario NVARCHAR(255) NOT NULL,
		Dia_de_Descanso NVARCHAR(255) NOT NULL,
		Morada NVARCHAR(255) NOT NULL,
		GPS NVARCHAR(255) ,
		Telefone NVARCHAR(255) NOT NULL,
		Takeway BIT NOT NULL,
		Entrega BIT NOT NULL,
		Local BIT NOT NULL
)

CREATE TABLE Prato_do_DiaAM
(
		PratoID INT NOT NULL,
		Nome NVARCHAR(255) NOT NULL,
		Preco FLOAT NOT NULL,
		Descricao NVARCHAR(255) NOT NULL,
		Foto NVARCHAR(255) NOT NULL,
		Data NVARCHAR(255) NOT NULL,
		RestauranteID INT NOT NULL,

		PRIMARY KEY(PratoID, Nome),
		CHECK (Nome < 'N')
)


CREATE TABLE Cliente
(
		ClienteID INT PRIMARY KEY
)


CREATE TABLE Preferencia_Prato
(
		ClienteID INT REFERENCES Cliente (ClienteID),
		PratoID INT  Not Null,
		PRIMARY KEY(ClienteID, PratoID) 
)

CREATE TABLE Preferencia_Restaurante
(
		ClienteID INT REFERENCES Cliente (ClienteID),
		RestauranteID INT REFERENCES Restaurante (RestauranteID),
		PRIMARY KEY(ClienteID, RestauranteID) 
)
GO

-- Criar views ************** 
-- Tabla Prato_do_Dia está distribuída pelos dois servers
CREATE View Prato_do_Dia
AS 
SELECT * FROM Prato_do_DiaAM
UNION ALL 
SELECT * FROM [server2].[TABD_TE2].[dbo].Prato_do_DiaNZ
GO

drop view Utilizador
-- Tabela Utilizador Distribuida
CREATE View Utilizador
AS
SELECT * FROM UtilizadorPar
UNION ALL
SELECT * FROM [server2].[TABD_TE2].[dbo].UtilizadorImpar
GO
-- Tabela Bloquear_Utilizadores está só no server2
CREATE View Bloquear_Utilizadores
AS 
SELECT * FROM [server2].[TABD_TE2].[dbo].Bloquear_Utilizadores
GO
-- Tabela Administrador está só no server2
CREATE View Administrador
AS 
SELECT * FROM [server2].[TABD_TE2].[dbo].Administrador
GO

--criar logins
CREATE LOGIN Cliente WITH PASSWORD= 'cliente'
CREATE LOGIN Restaurante WITH PASSWORD= 'restaurante'
CREATE LOGIN Administrador WITH PASSWORD= 'administrador'
CREATE LOGIN Convidado WITH PASSWORD= 'convidado'

EXEC sp_addlinkedsrvlogin @rmtsrvname = 'server2', @useself = 'TRUE'

--criar users
CREATE user Cliente_user for LOGIN Cliente
CREATE user Restaurante_user for LOGIN Restaurante
CREATE user Administrador_user for LOGIN Administrador
CREATE user Convidado_user for LOGIN Convidado

--permissoes do convidado
GRANT INSERT ON Cliente TO Convidado_user
GRANT INSERT, SELECT ON UtilizadorPar TO Convidado_user
GRANT INSERT, SELECT ON Restaurante TO Convidado_user
GRANT SELECT ON Prato_do_DiaAM TO Convidado_user

--permissoes do cliente
GRANT SELECT, UPDATE ON UtilizadorPar TO Cliente_user
GRANT SELECT, UPDATE ON Cliente TO Cliente_user
GRANT SELECT, INSERT, DELETE, UPDATE ON Preferencia_Restaurante TO Cliente_user
GRANT SELECT, INSERT, DELETE, UPDATE ON Preferencia_Prato TO Cliente_user
GRANT SELECT ON Restaurante TO Cliente_user
GRANT SELECT ON Prato_do_DiaAM TO Cliente_user

--permissoes do restaurante
GRANT SELECT, UPDATE ON UtilizadorPar TO Restaurante_user
GRANT SELECT, UPDATE ON Restaurante TO Restaurante_user
GRANT SELECT, INSERT, UPDATE, DELETE ON Prato_do_DiaAM TO Restaurante_user
GRANT SELECT, DELETE ON Preferencia_Prato TO Restaurante_user
															
--permissoes do administrador
GRANT SELECT, INSERT, UPDATE, DELETE ON Administrador TO Administrador_user
GRANT SELECT, INSERT, UPDATE, DELETE ON UtilizadorPar TO Administrador_user
GRANT SELECT, UPDATE ON Cliente TO Administrador_user
GRANT SELECT, UPDATE ON Restaurante TO Administrador_user 
GRANT SELECT, UPDATE, INSERT ON Bloquear_Utilizadores TO Administrador_user
GO

--**********************************************
--procedures Convidado
--**********************************************
CREATE PROCEDURE CriarCliente
		@Nome NVARCHAR(255),
		@Email NVARCHAR(255) ,
		@Password NVARCHAR(255),
		@Username NVARCHAR(255)
AS
SET TRANSACTION ISOLATION LEVEL READ COMMITTED
BEGIN DISTRIBUTED TRANSACTION

	DECLARE @max INTEGER
	SELECT @max = MAX(UserID) FROM Utilizador
	IF (@max IS NULL)
		SET @max = 0

	INSERT INTO Utilizador(
			UserID,
			Nome, 
			Email, 
			[Password],
			Username, 
			ValidarEmail, 
			Estado) 
	VALUES  (@max+1,
			@Nome, 
			@Email, 
			@Password,
			@Username, 
			0, 
			1)

	IF (@@ERROR <> 0) OR (@@ROWCOUNT = 0)
		GOTO ERRO

	INSERT INTO Cliente(ClienteID) VALUES (@max+1)
	IF (@@ERROR <> 0) OR (@@ROWCOUNT = 0)
		GOTO ERRO

	COMMIT
	RETURN 1
ERRO:
	ROLLBACK
	RETURN -1
GO


CREATE PROCEDURE CriarRestaurante
	@Nome VARCHAR(MAX),
	@Email VARCHAR(MAX),
	@Username VARCHAR(MAX),
	@Password VARCHAR(MAX),
	@ValidarEmail BIT,
	@Estado BIT,
	@Fotos VARCHAR(MAX),
	@Horario VARCHAR(MAX),
	@Dia_Descanso VARCHAR(MAX),
	@Morada VARCHAR(MAX),
	@GPS VARCHAR(MAX),
	@Telefone VARCHAR(MAX),
	@Takeaway BIT,
	@Entrega BIT,
	@Local BIT
AS
SET TRANSACTION ISOLATION LEVEL READ COMMITTED 
BEGIN DISTRIBUTED TRANSACTION

	DECLARE @max INTEGER
	SELECT @max = MAX(UserID) FROM Utilizador
	IF (@max IS NULL)
		SET @max = 0
	INSERT INTO Utilizador(
			UserID,
			Nome, 
			Email, 
			Username, 
			[Password], 
			ValidarEmail, 
			Estado)
	VALUES (@max+1,
			@Nome, 
			@Email, 
			@Username, 
			@Password, 
			0, 
			0)

	IF(@@ERROR <> 0) OR (@@ROWCOUNT = 0)
		GOTO ERRO

	INSERT INTO Restaurante(
			RestauranteID, 
			Fotos, Horario, 
			Dia_de_Descanso, 
			Morada, 
			GPS, 
			Telefone, 
			Takeway, 
			Entrega, 
			[Local])
	VALUES (@max+1, 
			@Fotos, 
			@Horario, 
			@Dia_Descanso, 
			@Morada, 
			@GPS, 
			@Telefone, 
			@Takeaway, 
			@Entrega, 
			@Local)

	IF(@@ERROR <> 0) OR (@@ROWCOUNT = 0)
		GOTO ERRO

	COMMIT
	RETURN 1

ERRO:
		ROLLBACK
		RETURN -1
GO

--Permissoes de procedures convidados
GRANT EXECUTE ON CriarCliente TO Convidado_user
GRANT EXECUTE ON CriarRestaurante TO Convidado_user
GO

--**********************************************
--procedures Clientes
--**********************************************
CREATE PROCEDURE RegistarPreferenciaPrato
		 @_ClienteID INT,
		 @_PratoID INT
AS
SET TRANSACTION ISOLATION LEVEL READ COMMITTED
BEGIN DISTRIBUTED TRANSACTION	
		
	DECLARE @aux INT;
	SELECT @aux = PratoID FROM Prato_do_Dia
	WHERE PratoID = @_PratoID
	IF (@@ERROR <>0 AND @@ROWCOUNT = 0)
		GOTO ERRO_ID_PRATO
		
	INSERT INTO Preferencia_Prato(
			[ClienteID]
           ,[PratoID])
	VALUES (@_ClienteID
           ,@_PratoID)
		
	IF (@@ERROR <> 0 or @@ROWCOUNT = 0)
    	GOTO ERRO_INSERT

COMMIT
		RETURN 0
		
ERRO_ID_PRATO:
		ROLLBACK
		RETURN -1

ERRO_INSERT:
		ROLLBACK
		RETURN -2
GO

--permissoes procedures Clientes
GRANT EXECUTE ON RegistarPreferenciaPrato TO Cliente_user
GO

--**********************************************
--procedures Restaurantes
--**********************************************
CREATE PROCEDURE AlterarRestaurante
	@ID_Utilizador INT,
	@Nome VARCHAR(MAX),
	@Email VARCHAR(MAX),
	@Username VARCHAR(MAX),
	@Password VARCHAR(MAX),
	@Fotos VARCHAR(MAX),
	@Horario VARCHAR(MAX),
	@Dia_Descanso VARCHAR(MAX),
	@Morada VARCHAR(MAX),
	@GPS VARCHAR(MAX),
	@Telefone VARCHAR(MAX),
	@Takeaway BIT,
	@Entrega BIT,
	@Local BIT
AS
SET TRANSACTION ISOLATION LEVEL READ COMMITTED 
BEGIN TRANSACTION
	UPDATE Utilizador
	SET Nome = @Nome, 
		Email = @Email, 
		Username = @Username, 
		[Password] = @Password
	WHERE (UserID = @ID_Utilizador)
	IF(@@ERROR <> 0) OR (@@ROWCOUNT = 0)
		GOTO ERRO
	
	UPDATE Restaurante
	SET Fotos = @Fotos, 
		Horario = @Horario, 
		Dia_de_Descanso = @Dia_Descanso, 
		Morada = @Morada, 
		GPS = @GPS,
		Telefone = @Telefone, 
		Takeway = @Takeaway, 
		Entrega = @Entrega, 
		[Local] = @Local
	WHERE (RestauranteID = @ID_Utilizador)
	IF(@@ERROR <> 0) OR (@@ROWCOUNT = 0)
		GOTO ERRO
	
	COMMIT
	RETURN 1

ERRO:
		ROLLBACK
		RETURN -1
GO


CREATE PROCEDURE RegistarPratoDia
		@_Nome NVARCHAR(255),
        @_Preco FLOAT,
        @_Descricao NVARCHAR(255),
        @_Foto NVARCHAR(255),
        @_Data NVARCHAR(255),
        @_RestauranteID INT
AS
SET TRANSACTION ISOLATION LEVEL READ COMMITTED
BEGIN DISTRIBUTED TRANSACTION

	DECLARE @aux INT
	SELECT @aux = RestauranteID FROM Restaurante
	WHERE RestauranteID = @_RestauranteID
	IF (@@ERROR <>0 AND @@ROWCOUNT = 0)
    	GOTO ERRO_ID_REST

	DECLARE @max INTEGER
	SELECT @max = MAX(UserID) FROM Utilizador
	IF (@max IS NULL)
		SET @max = 0

	INSERT INTO Prato_do_Dia(
			[PratoID]
           ,[Nome]
           ,[Preco]
           ,[Descricao]
           ,[Foto]
           ,[Data]
           ,[RestauranteID])
	VALUES (@max+1
           ,@_Nome
           ,@_Preco
           ,@_Descricao
           ,@_Foto
           ,@_Data
           ,@_RestauranteID)

	 IF (@@ERROR <> 0 or @@ROWCOUNT = 0)
     GOTO ERRO_INSERT

COMMIT
		RETURN 0

ERRO_ID_REST:
		ROLLBACK
		RETURN -1

ERRO_INSERT:
		ROLLBACK
		RETURN -2
GO

--permissoes procedures restaurantes
GRANT EXECUTE ON AlterarRestaurante TO Restaurante_user
GRANT EXECUTE ON RegistarPratoDia TO Restaurante_user
GO

--**********************************************
-- procedures Admins
--**********************************************
CREATE PROCEDURE CriarAdmin
		@Nome NVARCHAR(255),
		@Email NVARCHAR(255) ,
		@Password NVARCHAR(255),
		@Username NVARCHAR(255)			
AS
SET TRANSACTION ISOLATION LEVEL READ COMMITTED
BEGIN DISTRIBUTED TRANSACTION
	
	DECLARE @max INTEGER
	SELECT @max = MAX(UserID) FROM Utilizador
	IF (@max IS NULL)
		SET @max = 0
	INSERT INTO Utilizador(
			UserID,
			Nome, 
			Email, 
			Username, 
			[Password], 
			ValidarEmail, 
			Estado)
	VALUES (@max+1,
			@Nome, 
			@Email, 
			@Username, 
			@Password, 
			0, 
			0)

	IF(@@ERROR <> 0) OR (@@ROWCOUNT = 0)
		GOTO ERRO_USER

	INSERT INTO Administrador --(AdminID)
	VALUES (@max+1)

	 IF (@@ERROR <> 0 or @@ROWCOUNT = 0)
     GOTO ERRO_INSERT

COMMIT
		RETURN 0

ERRO_USER:
		ROLLBACK
		RETURN -1

ERRO_INSERT:
		ROLLBACK
		RETURN -2

GO


CREATE PROCEDURE Bloquear_Utilizador
	@ID_User INTEGER,
	@ID_Administrador INTEGER,
	@Motivo VARCHAR(MAX)
AS
SET TRANSACTION ISOLATION LEVEL READ COMMITTED 
BEGIN TRANSACTION

	DECLARE @aux INT
	SELECT @aux = UserID from Utilizador
	WHERE UserID = @ID_User
	IF (@@ERROR <>0 AND @@ROWCOUNT = 0)
    	GOTO ERRO_ID_USER

	INSERT INTO Bloquear_Utilizadores(
			UserID, 
			AdminID, 
			[Data_Bloqueio], 
			Motivo)
	VALUES (@ID_User, 
			@ID_Administrador, 
			GETDATE(), 
			@Motivo)

	IF(@@ERROR <> 0) OR (@@ROWCOUNT = 0)
		GOTO ERRO

	UPDATE Utilizador
	SET Estado = 0
	WHERE(UserID = @ID_User)

	IF(@@ERROR <> 0) OR (@@ROWCOUNT = 0)
		GOTO ERRO

COMMIT
RETURN 1

ERRO_ID_USER:
		ROLLBACK
		RETURN -1

ERRO:
		ROLLBACK
		RETURN -2
GO

--permissoes procedures admins
GRANT EXECUTE ON CriarAdmin TO Administrador_user
GRANT EXECUTE ON Bloquear_Utilizador to Administrador_user 
GO

