-- ============================================================
-- BASE DE DATOS: DB_EcoValeMercados  
-- PROYECTO 02: Registro de Envases Retornables para Mercados (ODS 12)
-- Grupo 01 · Análisis y Diseño de Software · Universidad Continental
-- Recreación en SQL Server del Capítulo VII (diseño detallado de la base de datos)
-- Regla RD-01: no existe ninguna columna monetaria (monto, multa, pago ni depósito).
-- ============================================================
-- Orden de ejecución: abrir en SQL Server Management Studio y ejecutar todo (F5).
-- Las contraseñas de los inicios de sesión de la sección 13 son de ejemplo: cámbielas.
-- ============================================================

USE master
GO

-- Permite volver a ejecutar el script desde cero
IF DB_ID('DB_EcoValeMercados') IS NOT NULL
BEGIN
	ALTER DATABASE DB_EcoValeMercados SET SINGLE_USER WITH ROLLBACK IMMEDIATE
	DROP DATABASE DB_EcoValeMercados
END
GO

CREATE DATABASE DB_EcoValeMercados
	COLLATE Modern_Spanish_CI_AS
GO


-- ============================================================
-- 1. USO DE LA BASE DE DATOS
-- ============================================================
USE DB_EcoValeMercados
GO

-- Opciones exigidas por los índices filtrados y la vista indexada (sección 8)
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET NUMERIC_ROUNDABORT OFF
GO


-- ============================================================
-- 2. VALORES POR DEFECTO
-- ============================================================
CREATE DEFAULT Fecha_Actual_Hoy
	AS SYSDATETIME()
GO

CREATE DEFAULT Valor_Cero
	AS 0
GO

CREATE DEFAULT Valor_Verdadero
	AS 1
GO

CREATE DEFAULT Valor_Falso
	AS 0
GO

CREATE DEFAULT Plazo_Vale_Siete_Dias          -- RD-03: plazo por defecto del mercado
	AS 7
GO

CREATE DEFAULT Estado_Comerciante_Inicial
	AS 'HABILITADO'
GO

CREATE DEFAULT Estado_Envase_Inicial
	AS 'DISPONIBLE'
GO

CREATE DEFAULT Estado_Vale_Inicial            -- RD-13: todo vale nace EMITIDO
	AS 'EMITIDO'
GO

CREATE DEFAULT Estado_Pendiente
	AS 'PENDIENTE'
GO

CREATE DEFAULT Estado_Incidencia_Inicial
	AS 'REGISTRADA'
GO


-- ============================================================
-- 3. REGLAS DE VALIDACIÓN
-- Equivalen a los tipos enumerados y a las expresiones regulares del
-- script PostgreSQL. Las reglas de columnas opcionales aceptan NULL.
-- ============================================================

-- 3.1 Dominios cerrados (sección 4.1 y máquina de estados RD-13)
CREATE RULE Regla_Rol_Usuario
	AS @col IN ('ADMINISTRADOR', 'ENCARGADO', 'COMERCIANTE')
GO

CREATE RULE Regla_Estado_Comerciante
	AS @col IN ('HABILITADO', 'RESTRINGIDO', 'INACTIVO')
GO

CREATE RULE Regla_Modo_Identificacion
	AS @col IN ('POR_UNIDAD', 'POR_CANTIDAD')
GO

CREATE RULE Regla_Estado_Envase
	AS @col IN ('DISPONIBLE', 'PRESTADO', 'EN_REVISION', 'DADO_DE_BAJA')
GO

CREATE RULE Regla_Causa_Baja
	AS @col IS NULL OR @col IN ('DANO', 'CONTAMINACION', 'EXTRAVIO', 'FIN_VIDA_UTIL')
GO

CREATE RULE Regla_Estado_Vale
	AS @col IN ('EMITIDO', 'VIGENTE', 'PARCIAL', 'VENCIDO', 'CERRADO', 'OBSERVADO', 'ANULADO')
GO

CREATE RULE Regla_Condicion_Envase
	AS @col IN ('APTO', 'REQUIERE_REVISION', 'NO_APTO')
GO

CREATE RULE Regla_Tipo_Incidencia
	AS @col IN ('DANO', 'CONTAMINACION', 'EXTRAVIO')
GO

CREATE RULE Regla_Estado_Incidencia
	AS @col IN ('REGISTRADA', 'VALIDADA', 'RECHAZADA', 'RESUELTA')
GO

CREATE RULE Regla_Canal_Notificacion
	AS @col IN ('WHATSAPP', 'SMS')
GO

CREATE RULE Regla_Estado_Envio
	AS @col IN ('PENDIENTE', 'ENVIADO', 'ENTREGADO', 'FALLIDO')
GO

CREATE RULE Regla_Tipo_Operacion
	AS @col IN ('PRESTAMO', 'DEVOLUCION', 'INCIDENCIA')
GO

CREATE RULE Regla_Estado_Sincronizacion
	AS @col IN ('PENDIENTE', 'SINCRONIZADA', 'DUPLICADA', 'EN_CONFLICTO', 'RESUELTA')
GO

CREATE RULE Regla_Accion_Bitacora
	AS @col IN ('CREAR', 'MODIFICAR', 'ANULAR', 'AJUSTAR', 'VALIDAR', 'SINCRONIZAR',
	            'INICIAR_SESION', 'INTENTO_FALLIDO', 'INTENTO_SOSPECHOSO')
GO

-- 3.2 Rangos numéricos
CREATE RULE Regla_Cantidad_Positiva
	AS @col > 0
GO

CREATE RULE Regla_Cantidad_No_Negativa
	AS @col >= 0
GO

CREATE RULE Regla_Plazo_Vale                  -- RD-03
	AS @col BETWEEN 1 AND 60
GO

CREATE RULE Regla_Intentos_Sesion             -- RF-02: bloqueo al quinto intento
	AS @col BETWEEN 0 AND 5
GO

CREATE RULE Regla_Intentos_Envio
	AS @col BETWEEN 0 AND 10
GO

CREATE RULE Regla_Porcentaje                  -- RN-24: índice de cumplimiento
	AS @col IS NULL OR @col BETWEEN 0 AND 100
GO

CREATE RULE Regla_Anio_Folio
	AS @col BETWEEN 2020 AND 2100
GO

-- 3.3 Formatos (sustituyen a las expresiones regulares de PostgreSQL)
CREATE RULE Regla_RUC
	AS LEN(@col) = 11 AND @col NOT LIKE '%[^0-9]%'
GO

CREATE RULE Regla_Codigo_Mercado              -- 2 a 10 mayúsculas o dígitos
	AS LEN(@col) BETWEEN 2 AND 10
	   AND @col COLLATE Latin1_General_BIN NOT LIKE '%[^A-Z0-9]%'
GO

CREATE RULE Regla_Documento_Identidad         -- RF-07: DNI (8) o RUC (11)
	AS LEN(@col) IN (8, 11) AND @col NOT LIKE '%[^0-9]%'
GO

CREATE RULE Regla_Telefono
	AS (@col LIKE '+%' AND LEN(@col) BETWEEN 10 AND 16
	    AND SUBSTRING(@col, 2, 15) NOT LIKE '%[^0-9]%')
	OR (LEN(@col) BETWEEN 9 AND 15 AND @col NOT LIKE '%[^0-9]%')
GO

CREATE RULE Regla_Hash_Bcrypt                 -- RF-02: solo se guarda el hash bcrypt
	AS @col LIKE '$2[aby]$%'
GO

CREATE RULE Regla_Folio_Vale                  -- RD-02: VAL-{MERCADO}-{AÑO}-{000000}
	AS LEN(@col) BETWEEN 18 AND 26
	   AND LEFT(@col, 4) COLLATE Latin1_General_BIN = 'VAL-'
	   AND @col LIKE 'VAL-%-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]'
	   AND SUBSTRING(@col, 5, LEN(@col) - 16) COLLATE Latin1_General_BIN NOT LIKE '%[^A-Z0-9]%'
GO

CREATE RULE Regla_Hex_64                      -- RNF-09: HMAC-SHA256 y huellas SHA-256
	AS @col IS NULL
	   OR (LEN(@col) = 64 AND @col COLLATE Latin1_General_BIN NOT LIKE '%[^0-9a-f]%')
GO

CREATE RULE Regla_Motivo_Ajuste               -- RF-13: motivo de al menos 10 caracteres
	AS LEN(LTRIM(RTRIM(@col))) >= 10
GO


-- ============================================================
-- 4. TABLAS SIN CLAVES FORÁNEAS
-- ============================================================

-- Tabla: municipalidad
CREATE TABLE municipalidad
(
	id_municipalidad     bigint        IDENTITY(1,1) NOT NULL,
	nombre               varchar(120)  NOT NULL,
	ruc                  char(11)      NOT NULL,
	distrito             varchar(60)   NOT NULL,
	CONSTRAINT XPKmunicipalidad PRIMARY KEY (id_municipalidad ASC),
	CONSTRAINT uq_municipalidad_ruc UNIQUE (ruc)
)
GO

-- Tabla: tipo_envase (catálogo, HU-05)
CREATE TABLE tipo_envase
(
	id_tipo              bigint        IDENTITY(1,1) NOT NULL,
	codigo               varchar(20)   NOT NULL,
	descripcion          varchar(120)  NOT NULL,
	material             varchar(40)   NOT NULL,
	capacidad            varchar(30)   NOT NULL,
	color                varchar(30)   NULL,
	modo_identificacion  varchar(12)   NOT NULL,                          -- RN-01
	vida_util_ciclos     int           NOT NULL,
	activo               bit           NOT NULL,
	CONSTRAINT XPKtipo_envase PRIMARY KEY (id_tipo ASC),
	CONSTRAINT uq_tipo_envase_codigo UNIQUE (codigo)
)
GO


-- ============================================================
-- 5. TABLAS CON CLAVES FORÁNEAS
-- Todas las FK usan NO ACTION (equivale a ON DELETE RESTRICT): ningún
-- registro referenciado puede eliminarse, en coherencia con RD-08.
-- ============================================================

-- Tabla: mercado (depende de municipalidad)
CREATE TABLE mercado
(
	id_mercado           bigint        IDENTITY(1,1) NOT NULL,
	id_municipalidad     bigint        NOT NULL,
	codigo               varchar(10)   NOT NULL,
	nombre               varchar(120)  NOT NULL,
	direccion            varchar(200)  NOT NULL,
	plazo_vale_dias      smallint      NOT NULL,                          -- RD-03
	activo               bit           NOT NULL,
	CONSTRAINT XPKmercado PRIMARY KEY (id_mercado ASC),
	CONSTRAINT uq_mercado_codigo UNIQUE (codigo),
	CONSTRAINT R_1 FOREIGN KEY (id_municipalidad)
		REFERENCES municipalidad (id_municipalidad)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: puesto (depende de mercado)
CREATE TABLE puesto
(
	id_puesto            bigint        IDENTITY(1,1) NOT NULL,
	id_mercado           bigint        NOT NULL,
	codigo               varchar(10)   NOT NULL,
	giro                 varchar(60)   NOT NULL,
	CONSTRAINT XPKpuesto PRIMARY KEY (id_puesto ASC),
	CONSTRAINT uq_puesto_codigo UNIQUE (id_mercado, codigo),             -- RF-06
	CONSTRAINT R_2 FOREIGN KEY (id_mercado)
		REFERENCES mercado (id_mercado)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: usuario (depende de mercado)
CREATE TABLE usuario
(
	id_usuario           bigint        IDENTITY(1,1) NOT NULL,
	id_mercado           bigint        NULL,
	nombre_usuario       varchar(40)   NOT NULL,
	hash_contrasena      varchar(100)  NOT NULL,
	rol                  varchar(15)   NOT NULL,
	intentos_fallidos    smallint      NOT NULL,
	bloqueado_hasta      datetime2(0)  NULL,                              -- RF-02
	activo               bit           NOT NULL,                          -- RF-04
	creado_en            datetime2(0)  NOT NULL,
	CONSTRAINT XPKusuario PRIMARY KEY (id_usuario ASC),
	CONSTRAINT uq_usuario_nombre UNIQUE (nombre_usuario),
	CONSTRAINT ck_usuario_mercado CHECK (rol = 'ADMINISTRADOR' OR id_mercado IS NOT NULL),
	CONSTRAINT R_3 FOREIGN KEY (id_mercado)
		REFERENCES mercado (id_mercado)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: comerciante (depende de puesto y usuario)
CREATE TABLE comerciante
(
	id_comerciante       bigint        IDENTITY(1,1) NOT NULL,
	id_puesto            bigint        NOT NULL,
	id_usuario           bigint        NULL,                              -- 0..1 (índice único filtrado)
	doc_identidad        varchar(11)   NOT NULL,                          -- RF-07
	nombres              varchar(120)  NOT NULL,
	telefono             varchar(16)   NOT NULL,
	consentimiento_datos bit           NOT NULL,                          -- RD-10
	estado               varchar(12)   NOT NULL,                          -- RF-09
	indice_cumplimiento  decimal(5,2)  NULL,                              -- RN-24
	fecha_registro       datetime2(0)  NOT NULL,
	CONSTRAINT XPKcomerciante PRIMARY KEY (id_comerciante ASC),
	CONSTRAINT uq_comerciante_documento UNIQUE (doc_identidad),
	CONSTRAINT ck_comerciante_consentimiento CHECK (consentimiento_datos = 1),
	CONSTRAINT R_4 FOREIGN KEY (id_puesto)
		REFERENCES puesto (id_puesto)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_5 FOREIGN KEY (id_usuario)
		REFERENCES usuario (id_usuario)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: dispositivo (dispositivo registrado, RN-25)
CREATE TABLE dispositivo
(
	id_dispositivo       varchar(40)   NOT NULL,
	id_mercado           bigint        NOT NULL,
	descripcion          varchar(80)   NOT NULL,
	activo               bit           NOT NULL,
	registrado_en        datetime2(0)  NOT NULL,
	CONSTRAINT XPKdispositivo PRIMARY KEY (id_dispositivo ASC),
	CONSTRAINT R_6 FOREIGN KEY (id_mercado)
		REFERENCES mercado (id_mercado)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: inventario_mercado (saldos POR_CANTIDAD, RN-03; resuelve la relación N:M)
CREATE TABLE inventario_mercado
(
	id_mercado           bigint        NOT NULL,
	id_tipo              bigint        NOT NULL,
	cant_disponible      int           NOT NULL,
	cant_prestada        int           NOT NULL,
	cant_revision        int           NOT NULL,
	cant_baja            int           NOT NULL,
	actualizado_en       datetime2(0)  NOT NULL,
	CONSTRAINT XPKinventario_mercado PRIMARY KEY (id_mercado ASC, id_tipo ASC),
	CONSTRAINT R_7 FOREIGN KEY (id_mercado)
		REFERENCES mercado (id_mercado)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_8 FOREIGN KEY (id_tipo)
		REFERENCES tipo_envase (id_tipo)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: envase_unidad (unidades serializadas POR_UNIDAD)
CREATE TABLE envase_unidad
(
	id_unidad            bigint        IDENTITY(1,1) NOT NULL,
	id_tipo              bigint        NOT NULL,
	id_mercado           bigint        NOT NULL,
	serial               varchar(30)   NOT NULL,                          -- RF-11
	grai                 varchar(30)   NULL,                              -- GS1 GRAI (índice único filtrado)
	ciclos_realizados    int           NOT NULL,
	estado               varchar(15)   NOT NULL,
	fecha_alta           datetime2(0)  NOT NULL,
	causa_baja           varchar(15)   NULL,
	CONSTRAINT XPKenvase_unidad PRIMARY KEY (id_unidad ASC),
	CONSTRAINT uq_envase_unidad_serial UNIQUE (serial),
	CONSTRAINT ck_unidad_baja CHECK ((estado = 'DADO_DE_BAJA' AND causa_baja IS NOT NULL)
	                              OR (estado <> 'DADO_DE_BAJA' AND causa_baja IS NULL)),
	CONSTRAINT R_9 FOREIGN KEY (id_tipo)
		REFERENCES tipo_envase (id_tipo)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_10 FOREIGN KEY (id_mercado)
		REFERENCES mercado (id_mercado)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: operacion_sincronizacion (operaciones sin conexión, RN-26 a RN-34)
CREATE TABLE operacion_sincronizacion
(
	id_operacion          uniqueidentifier NOT NULL,                     -- UUID generado en el dispositivo
	id_dispositivo        varchar(40)   NOT NULL,
	id_usuario            bigint        NOT NULL,
	tipo_operacion        varchar(12)   NOT NULL,
	secuencia_local       int           NOT NULL,
	fecha_hora_local      datetime2(0)  NOT NULL,
	fecha_hora_recepcion  datetime2(0)  NOT NULL,
	huella_contenido      char(64)      NOT NULL,
	estado_sincronizacion varchar(15)   NOT NULL,
	entidad_resultante    varchar(30)   NULL,
	id_entidad_resultante bigint        NULL,
	detalle_conflicto     varchar(1000) NULL,
	id_usuario_resuelve   bigint        NULL,
	fecha_resolucion      datetime2(0)  NULL,
	CONSTRAINT XPKoperacion_sincronizacion PRIMARY KEY (id_operacion ASC),
	CONSTRAINT uq_operacion_secuencia UNIQUE (id_dispositivo, secuencia_local),   -- RN-27
	CONSTRAINT ck_operacion_resuelta CHECK (estado_sincronizacion <> 'RESUELTA'
	                                     OR id_usuario_resuelve IS NOT NULL),
	CONSTRAINT R_11 FOREIGN KEY (id_dispositivo)
		REFERENCES dispositivo (id_dispositivo)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_12 FOREIGN KEY (id_usuario)
		REFERENCES usuario (id_usuario)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_13 FOREIGN KEY (id_usuario_resuelve)
		REFERENCES usuario (id_usuario)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: serie_folio (correlativo por mercado y año, RD-02)
CREATE TABLE serie_folio
(
	id_mercado           bigint        NOT NULL,
	anio                 smallint      NOT NULL,
	ultimo_correlativo   int           NOT NULL,
	CONSTRAINT XPKserie_folio PRIMARY KEY (id_mercado ASC, anio ASC),
	CONSTRAINT R_14 FOREIGN KEY (id_mercado)
		REFERENCES mercado (id_mercado)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: vale (depende de mercado, comerciante, usuario y operacion_sincronizacion)
-- La PK es NONCLUSTERED: el índice CLUSTERED se crea por mercado y fecha (sección 8).
CREATE TABLE vale
(
	id_vale              bigint        IDENTITY(1,1) NOT NULL,
	folio                varchar(30)   NOT NULL,                          -- RD-02
	id_mercado           bigint        NOT NULL,
	id_comerciante       bigint        NOT NULL,
	id_usuario_emisor    bigint        NOT NULL,
	fecha_emision        datetime2(0)  NOT NULL,
	fecha_limite         datetime2(0)  NOT NULL,                          -- RD-03
	estado               varchar(12)   NOT NULL,                          -- RD-13
	firma_qr             char(64)      NULL,                              -- HMAC-SHA256 (RNF-09)
	motivo_anulacion     varchar(500)  NULL,
	origen_offline       bit           NOT NULL,
	folio_provisional    varchar(40)   NULL,                              -- RN-28 (índice único filtrado)
	fecha_cierre         datetime2(0)  NULL,
	cerrado_fuera_plazo  bit           NOT NULL,                          -- RN-19
	id_operacion         uniqueidentifier NULL,                           -- índice único filtrado
	CONSTRAINT XPKvale PRIMARY KEY NONCLUSTERED (id_vale ASC),
	CONSTRAINT vale_folio_key UNIQUE NONCLUSTERED (folio),
	CONSTRAINT ck_vale_plazo CHECK (fecha_limite > fecha_emision),
	CONSTRAINT ck_vale_anulacion CHECK ((estado = 'ANULADO' AND motivo_anulacion IS NOT NULL)
	                                 OR (estado <> 'ANULADO' AND motivo_anulacion IS NULL)),
	CONSTRAINT ck_vale_cierre CHECK ((estado IN ('CERRADO', 'OBSERVADO') AND fecha_cierre IS NOT NULL)
	                              OR (estado NOT IN ('CERRADO', 'OBSERVADO') AND fecha_cierre IS NULL)),
	CONSTRAINT ck_vale_offline CHECK ((origen_offline = 1 AND folio_provisional IS NOT NULL)
	                               OR (origen_offline = 0 AND folio_provisional IS NULL)),
	CONSTRAINT R_15 FOREIGN KEY (id_mercado)
		REFERENCES mercado (id_mercado)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_16 FOREIGN KEY (id_comerciante)
		REFERENCES comerciante (id_comerciante)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_17 FOREIGN KEY (id_usuario_emisor)
		REFERENCES usuario (id_usuario)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_18 FOREIGN KEY (id_operacion)
		REFERENCES operacion_sincronizacion (id_operacion)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: detalle_vale (depende de vale, tipo_envase y envase_unidad)
CREATE TABLE detalle_vale
(
	id_detalle           bigint        IDENTITY(1,1) NOT NULL,
	id_vale              bigint        NOT NULL,
	id_tipo              bigint        NOT NULL,
	id_unidad            bigint        NULL,
	cantidad             int           NOT NULL,
	cantidad_devuelta    int           NOT NULL,
	cantidad_extraviada  int           NOT NULL,
	cantidad_transferida int           NOT NULL,
	CONSTRAINT XPKdetalle_vale PRIMARY KEY NONCLUSTERED (id_detalle ASC),
	CONSTRAINT ck_detalle_saldo CHECK                                    -- RD-05, RN-03
		(cantidad_devuelta + cantidad_extraviada + cantidad_transferida <= cantidad),
	CONSTRAINT ck_detalle_modalidad CHECK                                -- RN-02
		((id_unidad IS NOT NULL AND cantidad = 1) OR id_unidad IS NULL),
	CONSTRAINT R_19 FOREIGN KEY (id_vale)
		REFERENCES vale (id_vale)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_20 FOREIGN KEY (id_tipo)
		REFERENCES tipo_envase (id_tipo)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_21 FOREIGN KEY (id_unidad)
		REFERENCES envase_unidad (id_unidad)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: devolucion (depende de vale, usuario y operacion_sincronizacion)
CREATE TABLE devolucion
(
	id_devolucion        bigint        IDENTITY(1,1) NOT NULL,
	id_vale              bigint        NOT NULL,
	id_usuario_receptor  bigint        NOT NULL,
	fecha_hora           datetime2(0)  NOT NULL,                          -- fecha de ocurrencia
	observacion          varchar(500)  NULL,
	origen_offline       bit           NOT NULL,
	id_operacion         uniqueidentifier NULL,                           -- índice único filtrado
	CONSTRAINT XPKdevolucion PRIMARY KEY NONCLUSTERED (id_devolucion ASC),
	CONSTRAINT R_22 FOREIGN KEY (id_vale)
		REFERENCES vale (id_vale)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_23 FOREIGN KEY (id_usuario_receptor)
		REFERENCES usuario (id_usuario)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_24 FOREIGN KEY (id_operacion)
		REFERENCES operacion_sincronizacion (id_operacion)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: detalle_devolucion (depende de devolucion y detalle_vale)
CREATE TABLE detalle_devolucion
(
	id_det_dev           bigint        IDENTITY(1,1) NOT NULL,
	id_devolucion        bigint        NOT NULL,
	id_detalle_vale      bigint        NOT NULL,
	cantidad             int           NOT NULL,
	condicion            varchar(20)   NOT NULL,                          -- RF-23
	CONSTRAINT XPKdetalle_devolucion PRIMARY KEY (id_det_dev ASC),
	CONSTRAINT uq_det_dev_condicion UNIQUE (id_devolucion, id_detalle_vale, condicion),
	CONSTRAINT R_25 FOREIGN KEY (id_devolucion)
		REFERENCES devolucion (id_devolucion)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_26 FOREIGN KEY (id_detalle_vale)
		REFERENCES detalle_vale (id_detalle)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: incidencia (depende de vale, detalle_devolucion, detalle_vale, envase_unidad y usuario)
CREATE TABLE incidencia
(
	id_incidencia        bigint        IDENTITY(1,1) NOT NULL,
	id_vale              bigint        NOT NULL,
	id_det_dev           bigint        NULL,
	id_detalle_vale      bigint        NULL,
	id_unidad            bigint        NULL,
	tipo                 varchar(15)   NOT NULL,
	descripcion          varchar(500)  NOT NULL,
	url_evidencia        varchar(300)  NULL,
	cantidad_afectada    int           NOT NULL,
	cantidad_recuperada  int           NOT NULL,
	estado_incidencia    varchar(12)   NOT NULL,
	id_usuario_registra  bigint        NOT NULL,
	id_usuario_valida    bigint        NULL,
	fecha_hora           datetime2(0)  NOT NULL,
	fecha_validacion     datetime2(0)  NULL,
	CONSTRAINT XPKincidencia PRIMARY KEY (id_incidencia ASC),
	CONSTRAINT ck_incidencia_origen CHECK (id_det_dev IS NOT NULL OR id_detalle_vale IS NOT NULL),
	CONSTRAINT ck_incidencia_evidencia CHECK (tipo = 'EXTRAVIO' OR url_evidencia IS NOT NULL),
	CONSTRAINT ck_incidencia_recupera CHECK (cantidad_recuperada BETWEEN 0 AND cantidad_afectada),
	CONSTRAINT ck_incidencia_funciones CHECK                             -- RN-14
		(id_usuario_valida IS NULL OR id_usuario_valida <> id_usuario_registra),
	CONSTRAINT R_27 FOREIGN KEY (id_vale)
		REFERENCES vale (id_vale)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_28 FOREIGN KEY (id_det_dev)
		REFERENCES detalle_devolucion (id_det_dev)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_29 FOREIGN KEY (id_detalle_vale)
		REFERENCES detalle_vale (id_detalle)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_30 FOREIGN KEY (id_unidad)
		REFERENCES envase_unidad (id_unidad)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_31 FOREIGN KEY (id_usuario_registra)
		REFERENCES usuario (id_usuario)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_32 FOREIGN KEY (id_usuario_valida)
		REFERENCES usuario (id_usuario)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: ajuste_inventario (ajustes con motivo, RF-13)
CREATE TABLE ajuste_inventario
(
	id_ajuste            bigint        IDENTITY(1,1) NOT NULL,
	id_mercado           bigint        NOT NULL,
	id_tipo              bigint        NOT NULL,
	id_unidad            bigint        NULL,
	estado_origen        varchar(15)   NOT NULL,
	estado_destino       varchar(15)   NOT NULL,
	cantidad             int           NOT NULL,
	motivo               varchar(500)  NOT NULL,
	id_usuario           bigint        NOT NULL,
	id_incidencia        bigint        NULL,
	id_operacion         uniqueidentifier NULL,
	fecha_hora           datetime2(0)  NOT NULL,
	CONSTRAINT XPKajuste_inventario PRIMARY KEY (id_ajuste ASC),
	CONSTRAINT ck_ajuste_estados CHECK (estado_origen <> estado_destino),
	CONSTRAINT R_33 FOREIGN KEY (id_mercado)
		REFERENCES mercado (id_mercado)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_34 FOREIGN KEY (id_tipo)
		REFERENCES tipo_envase (id_tipo)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_35 FOREIGN KEY (id_unidad)
		REFERENCES envase_unidad (id_unidad)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_36 FOREIGN KEY (id_usuario)
		REFERENCES usuario (id_usuario)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_37 FOREIGN KEY (id_incidencia)
		REFERENCES incidencia (id_incidencia)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_38 FOREIGN KEY (id_operacion)
		REFERENCES operacion_sincronizacion (id_operacion)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: notificacion (depende de comerciante y vale)
CREATE TABLE notificacion
(
	id_notificacion      bigint        IDENTITY(1,1) NOT NULL,
	id_comerciante       bigint        NOT NULL,
	id_vale              bigint        NOT NULL,
	canal                varchar(10)   NOT NULL,
	mensaje              varchar(500)  NOT NULL,
	estado_envio         varchar(10)   NOT NULL,
	intentos             smallint      NOT NULL,
	fecha_envio          datetime2(0)  NULL,
	CONSTRAINT XPKnotificacion PRIMARY KEY (id_notificacion ASC),
	CONSTRAINT R_39 FOREIGN KEY (id_comerciante)
		REFERENCES comerciante (id_comerciante)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION,
	CONSTRAINT R_40 FOREIGN KEY (id_vale)
		REFERENCES vale (id_vale)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

-- Tabla: bitacora (solo inserción, RD-08 y RF-36)
CREATE TABLE bitacora
(
	id_evento            bigint        IDENTITY(1,1) NOT NULL,
	id_usuario           bigint        NULL,                              -- NULL = proceso programado
	entidad              varchar(40)   NOT NULL,
	id_entidad           varchar(40)   NOT NULL,
	accion               varchar(20)   NOT NULL,
	valor_anterior       nvarchar(max) NULL,                              -- JSON
	valor_nuevo          nvarchar(max) NULL,                              -- JSON
	dispositivo          varchar(80)   NULL,
	ip                   varchar(45)   NULL,
	fecha_hora           datetime2(0)  NOT NULL,
	CONSTRAINT XPKbitacora PRIMARY KEY (id_evento ASC),
	CONSTRAINT ck_bitacora_json CHECK ((valor_anterior IS NULL OR ISJSON(valor_anterior) = 1)
	                                AND (valor_nuevo IS NULL OR ISJSON(valor_nuevo) = 1)),
	CONSTRAINT R_41 FOREIGN KEY (id_usuario)
		REFERENCES usuario (id_usuario)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO


-- ============================================================
-- 6. ASOCIACIÓN DE VALORES POR DEFECTO A COLUMNAS
-- ============================================================

-- Fechas de registro
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'usuario.creado_en'
GO
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'comerciante.fecha_registro'
GO
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'dispositivo.registrado_en'
GO
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'inventario_mercado.actualizado_en'
GO
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'envase_unidad.fecha_alta'
GO
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'operacion_sincronizacion.fecha_hora_recepcion'
GO
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'vale.fecha_emision'
GO
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'devolucion.fecha_hora'
GO
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'incidencia.fecha_hora'
GO
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'ajuste_inventario.fecha_hora'
GO
EXEC sp_bindefault 'Fecha_Actual_Hoy', 'bitacora.fecha_hora'
GO

-- Contadores y saldos que inician en cero
EXEC sp_bindefault 'Valor_Cero', 'usuario.intentos_fallidos'
GO
EXEC sp_bindefault 'Valor_Cero', 'inventario_mercado.cant_disponible'
GO
EXEC sp_bindefault 'Valor_Cero', 'inventario_mercado.cant_prestada'
GO
EXEC sp_bindefault 'Valor_Cero', 'inventario_mercado.cant_revision'
GO
EXEC sp_bindefault 'Valor_Cero', 'inventario_mercado.cant_baja'
GO
EXEC sp_bindefault 'Valor_Cero', 'envase_unidad.ciclos_realizados'
GO
EXEC sp_bindefault 'Valor_Cero', 'serie_folio.ultimo_correlativo'
GO
EXEC sp_bindefault 'Valor_Cero', 'detalle_vale.cantidad_devuelta'
GO
EXEC sp_bindefault 'Valor_Cero', 'detalle_vale.cantidad_extraviada'
GO
EXEC sp_bindefault 'Valor_Cero', 'detalle_vale.cantidad_transferida'
GO
EXEC sp_bindefault 'Valor_Cero', 'incidencia.cantidad_recuperada'
GO
EXEC sp_bindefault 'Valor_Cero', 'notificacion.intentos'
GO

-- Indicadores lógicos
EXEC sp_bindefault 'Valor_Verdadero', 'mercado.activo'
GO
EXEC sp_bindefault 'Valor_Verdadero', 'usuario.activo'
GO
EXEC sp_bindefault 'Valor_Verdadero', 'dispositivo.activo'
GO
EXEC sp_bindefault 'Valor_Verdadero', 'tipo_envase.activo'
GO
EXEC sp_bindefault 'Valor_Falso', 'vale.origen_offline'
GO
EXEC sp_bindefault 'Valor_Falso', 'vale.cerrado_fuera_plazo'
GO
EXEC sp_bindefault 'Valor_Falso', 'devolucion.origen_offline'
GO

-- Plazo y estados iniciales
EXEC sp_bindefault 'Plazo_Vale_Siete_Dias', 'mercado.plazo_vale_dias'
GO
EXEC sp_bindefault 'Estado_Comerciante_Inicial', 'comerciante.estado'
GO
EXEC sp_bindefault 'Estado_Envase_Inicial', 'envase_unidad.estado'
GO
EXEC sp_bindefault 'Estado_Vale_Inicial', 'vale.estado'
GO
EXEC sp_bindefault 'Estado_Pendiente', 'operacion_sincronizacion.estado_sincronizacion'
GO
EXEC sp_bindefault 'Estado_Pendiente', 'notificacion.estado_envio'
GO
EXEC sp_bindefault 'Estado_Incidencia_Inicial', 'incidencia.estado_incidencia'
GO


-- ============================================================
-- 7. ASOCIACIÓN DE REGLAS A COLUMNAS
-- ============================================================

-- municipalidad
EXEC sp_bindrule 'Regla_RUC',                   'municipalidad.ruc'
GO

-- mercado
EXEC sp_bindrule 'Regla_Codigo_Mercado',        'mercado.codigo'
GO
EXEC sp_bindrule 'Regla_Plazo_Vale',            'mercado.plazo_vale_dias'
GO

-- usuario
EXEC sp_bindrule 'Regla_Hash_Bcrypt',           'usuario.hash_contrasena'
GO
EXEC sp_bindrule 'Regla_Rol_Usuario',           'usuario.rol'
GO
EXEC sp_bindrule 'Regla_Intentos_Sesion',       'usuario.intentos_fallidos'
GO

-- comerciante
EXEC sp_bindrule 'Regla_Documento_Identidad',   'comerciante.doc_identidad'
GO
EXEC sp_bindrule 'Regla_Telefono',              'comerciante.telefono'
GO
EXEC sp_bindrule 'Regla_Estado_Comerciante',    'comerciante.estado'
GO
EXEC sp_bindrule 'Regla_Porcentaje',            'comerciante.indice_cumplimiento'
GO

-- tipo_envase
EXEC sp_bindrule 'Regla_Modo_Identificacion',   'tipo_envase.modo_identificacion'
GO
EXEC sp_bindrule 'Regla_Cantidad_Positiva',     'tipo_envase.vida_util_ciclos'
GO

-- inventario_mercado
EXEC sp_bindrule 'Regla_Cantidad_No_Negativa',  'inventario_mercado.cant_disponible'
GO
EXEC sp_bindrule 'Regla_Cantidad_No_Negativa',  'inventario_mercado.cant_prestada'
GO
EXEC sp_bindrule 'Regla_Cantidad_No_Negativa',  'inventario_mercado.cant_revision'
GO
EXEC sp_bindrule 'Regla_Cantidad_No_Negativa',  'inventario_mercado.cant_baja'
GO

-- envase_unidad
EXEC sp_bindrule 'Regla_Cantidad_No_Negativa',  'envase_unidad.ciclos_realizados'
GO
EXEC sp_bindrule 'Regla_Estado_Envase',         'envase_unidad.estado'
GO
EXEC sp_bindrule 'Regla_Causa_Baja',            'envase_unidad.causa_baja'
GO

-- operacion_sincronizacion
EXEC sp_bindrule 'Regla_Tipo_Operacion',        'operacion_sincronizacion.tipo_operacion'
GO
EXEC sp_bindrule 'Regla_Cantidad_Positiva',     'operacion_sincronizacion.secuencia_local'
GO
EXEC sp_bindrule 'Regla_Hex_64',                'operacion_sincronizacion.huella_contenido'
GO
EXEC sp_bindrule 'Regla_Estado_Sincronizacion', 'operacion_sincronizacion.estado_sincronizacion'
GO

-- serie_folio
EXEC sp_bindrule 'Regla_Anio_Folio',            'serie_folio.anio'
GO
EXEC sp_bindrule 'Regla_Cantidad_No_Negativa',  'serie_folio.ultimo_correlativo'
GO

-- vale
EXEC sp_bindrule 'Regla_Folio_Vale',            'vale.folio'
GO
EXEC sp_bindrule 'Regla_Estado_Vale',           'vale.estado'
GO
EXEC sp_bindrule 'Regla_Hex_64',                'vale.firma_qr'
GO

-- detalle_vale
EXEC sp_bindrule 'Regla_Cantidad_Positiva',     'detalle_vale.cantidad'
GO
EXEC sp_bindrule 'Regla_Cantidad_No_Negativa',  'detalle_vale.cantidad_devuelta'
GO
EXEC sp_bindrule 'Regla_Cantidad_No_Negativa',  'detalle_vale.cantidad_extraviada'
GO
EXEC sp_bindrule 'Regla_Cantidad_No_Negativa',  'detalle_vale.cantidad_transferida'
GO

-- detalle_devolucion
EXEC sp_bindrule 'Regla_Cantidad_Positiva',     'detalle_devolucion.cantidad'
GO
EXEC sp_bindrule 'Regla_Condicion_Envase',      'detalle_devolucion.condicion'
GO

-- incidencia
EXEC sp_bindrule 'Regla_Tipo_Incidencia',       'incidencia.tipo'
GO
EXEC sp_bindrule 'Regla_Cantidad_Positiva',     'incidencia.cantidad_afectada'
GO
EXEC sp_bindrule 'Regla_Estado_Incidencia',     'incidencia.estado_incidencia'
GO

-- ajuste_inventario
EXEC sp_bindrule 'Regla_Estado_Envase',         'ajuste_inventario.estado_origen'
GO
EXEC sp_bindrule 'Regla_Estado_Envase',         'ajuste_inventario.estado_destino'
GO
EXEC sp_bindrule 'Regla_Cantidad_Positiva',     'ajuste_inventario.cantidad'
GO
EXEC sp_bindrule 'Regla_Motivo_Ajuste',         'ajuste_inventario.motivo'
GO

-- notificacion
EXEC sp_bindrule 'Regla_Canal_Notificacion',    'notificacion.canal'
GO
EXEC sp_bindrule 'Regla_Estado_Envio',          'notificacion.estado_envio'
GO
EXEC sp_bindrule 'Regla_Intentos_Envio',        'notificacion.intentos'
GO

-- bitacora
EXEC sp_bindrule 'Regla_Accion_Bitacora',       'bitacora.accion'
GO


-- ============================================================
-- 8. ÍNDICES CLUSTERED Y NON-CLUSTERED
-- En SQL Server la tabla se ordena físicamente según su índice CLUSTERED
-- (uno por tabla). Por defecto la PK es CLUSTERED; en vale, detalle_vale y
-- devolucion la PK se declaró NONCLUSTERED para agrupar por el orden que
-- favorece las consultas de rango más frecuentes (ver estadísticas del cap. VII).
-- ============================================================

-- 8.1 Índices CLUSTERED (orden físico de la tabla)
-- RF-33 y proceso 00:05: vales contiguos por mercado y fecha de emisión
CREATE CLUSTERED INDEX ix_vale_mercado_emision
	ON vale (id_mercado ASC, fecha_emision ASC)
GO
-- CU-07: líneas de un mismo vale en páginas contiguas
CREATE CLUSTERED INDEX ix_detalle_vale_vale
	ON detalle_vale (id_vale ASC)
GO
-- Historial de devoluciones del vale
CREATE CLUSTERED INDEX ix_devolucion_vale
	ON devolucion (id_vale ASC, fecha_hora ASC)
GO

-- 8.2 Índices NON-CLUSTERED sobre claves foráneas usadas en uniones críticas
CREATE NONCLUSTERED INDEX ix_det_dev_detalle
	ON detalle_devolucion (id_detalle_vale ASC)
GO
CREATE NONCLUSTERED INDEX ix_comerciante_puesto
	ON comerciante (id_puesto ASC)
GO
CREATE NONCLUSTERED INDEX ix_incidencia_vale
	ON incidencia (id_vale ASC)
GO

-- 8.3 RF-15 / RN-23 (¿tiene vales VENCIDOS?) y RF-31 (pendientes): índice cubriente
CREATE NONCLUSTERED INDEX ix_vale_comerciante_estado
	ON vale (id_comerciante ASC, estado ASC)
	INCLUDE (fecha_limite)
GO

-- 8.4 RF-29 (proceso 00:05) y RF-30 (aviso 24 h): índice filtrado, solo vales abiertos
CREATE NONCLUSTERED INDEX ix_vale_abiertos_limite
	ON vale (fecha_limite ASC)
	WHERE estado IN ('VIGENTE', 'PARCIAL')
GO

-- 8.5 RF-12: inventario de unidades por mercado, tipo y estado
CREATE NONCLUSTERED INDEX ix_unidad_mercado_tipo_estado
	ON envase_unidad (id_mercado ASC, id_tipo ASC, estado ASC)
GO

-- 8.6 HU-21: bitácora por entidad y por rango de fechas. La bitácora ya está
--     ordenada en el tiempo por su PK CLUSTERED (identidad creciente); el índice
--     por fecha usa compresión de página, equivalente práctico del BRIN de PostgreSQL.
CREATE NONCLUSTERED INDEX ix_bitacora_entidad
	ON bitacora (entidad ASC, id_entidad ASC, fecha_hora DESC)
GO
CREATE NONCLUSTERED INDEX ix_bitacora_fecha
	ON bitacora (fecha_hora ASC)
	WITH (DATA_COMPRESSION = PAGE)
GO

-- 8.7 Colas de trabajo: notificaciones pendientes y conflictos por resolver (RN-34)
CREATE NONCLUSTERED INDEX ix_notificacion_pendiente
	ON notificacion (id_vale ASC)
	WHERE estado_envio = 'PENDIENTE'
GO
CREATE NONCLUSTERED INDEX ix_operacion_conflicto
	ON operacion_sincronizacion (fecha_hora_recepcion ASC)
	WHERE estado_sincronizacion = 'EN_CONFLICTO'
GO

-- 8.8 Unicidad de columnas opcionales. En SQL Server una restricción UNIQUE admite
--     un solo NULL; los índices únicos filtrados permiten varios NULL.
CREATE UNIQUE NONCLUSTERED INDEX ux_comerciante_usuario
	ON comerciante (id_usuario) WHERE id_usuario IS NOT NULL            -- cuenta 0..1
GO
CREATE UNIQUE NONCLUSTERED INDEX ux_unidad_grai
	ON envase_unidad (grai) WHERE grai IS NOT NULL
GO
CREATE UNIQUE NONCLUSTERED INDEX ux_vale_folio_provisional
	ON vale (folio_provisional) WHERE folio_provisional IS NOT NULL     -- RN-28
GO
CREATE UNIQUE NONCLUSTERED INDEX ux_vale_operacion
	ON vale (id_operacion) WHERE id_operacion IS NOT NULL               -- RN-27
GO
CREATE UNIQUE NONCLUSTERED INDEX ux_devolucion_operacion
	ON devolucion (id_operacion) WHERE id_operacion IS NOT NULL         -- RN-27
GO

-- 8.9 RN-06: una unidad no puede estar en dos vales con saldo pendiente.
--     Un índice filtrado no admite expresiones; se usa una vista indexada
--     cuyo índice CLUSTERED ÚNICO rechaza la segunda línea con saldo.
CREATE VIEW dbo.v_unidad_con_saldo
WITH SCHEMABINDING
AS
SELECT id_detalle, id_unidad
  FROM dbo.detalle_vale
 WHERE id_unidad IS NOT NULL
   AND cantidad_devuelta + cantidad_extraviada + cantidad_transferida < cantidad
GO
CREATE UNIQUE CLUSTERED INDEX ux_detalle_unidad_pendiente
	ON dbo.v_unidad_con_saldo (id_unidad)
GO

-- 8.10 Estadísticas de columnas usadas en filtros de estado
CREATE STATISTICS st_vale_estado          ON vale (estado) WITH FULLSCAN
GO
CREATE STATISTICS st_comerciante_estado   ON comerciante (estado) WITH FULLSCAN
GO
CREATE STATISTICS st_det_dev_condicion    ON detalle_devolucion (condicion) WITH FULLSCAN
GO


-- ============================================================
-- 9. FUNCIONES
-- Errores de negocio (la API los traduce a HTTP):
--   50001 EV001 comerciante RESTRINGIDO (403)   50002 EV002 stock insuficiente (409)
--   50003 EV003 unidad no disponible (409)      50004 EV004 saldo excedido o doble registro (422)
--   50005 EV005 el vale no admite la operación (422)
--   50006 EV006 permiso o separación de funciones (403)
--   50000 EV000 datos de entrada no válidos (400)
-- ============================================================

-- 9.1 HMAC-SHA256 (RFC 2104) construido sobre HASHBYTES, que SQL Server trae de fábrica
CREATE FUNCTION dbo.fn_hmac_sha256
(
	@clave   varbinary(256),
	@mensaje varbinary(max)
)
RETURNS binary(32)
AS
BEGIN
	DECLARE @k varbinary(64), @ipad varbinary(64) = 0x, @opad varbinary(64) = 0x,
	        @i int = 1, @b tinyint;

	IF DATALENGTH(@clave) > 64
		SET @k = HASHBYTES('SHA2_256', @clave);
	ELSE
		SET @k = @clave;

	WHILE @i <= 64
	BEGIN
		SET @b = CASE WHEN @i <= DATALENGTH(@k) THEN CAST(SUBSTRING(@k, @i, 1) AS tinyint) ELSE 0 END;
		SET @ipad = @ipad + CAST(CAST(@b ^ 54 AS tinyint) AS binary(1));   -- 0x36
		SET @opad = @opad + CAST(CAST(@b ^ 92 AS tinyint) AS binary(1));   -- 0x5C
		SET @i += 1;
	END

	RETURN HASHBYTES('SHA2_256', @opad + HASHBYTES('SHA2_256', @ipad + @mensaje));
END
GO

-- 9.2 Firma del QR del vale (RNF-09). La clave la fija la API en cada sesión
--     con sp_set_session_context 'clave_hmac' desde el gestor de secretos; nunca se guarda.
CREATE FUNCTION dbo.fn_firmar_vale
(
	@folio   varchar(30),
	@emision datetime2(0),
	@limite  datetime2(0)
)
RETURNS char(64)
AS
BEGIN
	DECLARE @clave varchar(256) = CAST(SESSION_CONTEXT(N'clave_hmac') AS varchar(256));
	IF @clave IS NULL
		RETURN NULL;

	DECLARE @mensaje varchar(200) =
		CONCAT(@folio, '|', DATEDIFF_BIG(SECOND, '19700101', @emision),
		               '|', DATEDIFF_BIG(SECOND, '19700101', @limite));

	RETURN LOWER(CONVERT(char(64),
	       dbo.fn_hmac_sha256(CAST(@clave AS varbinary(256)), CAST(@mensaje AS varbinary(max))), 2));
END
GO

-- 9.3 Saldo pendiente de un vale (sección 2.6.1)
CREATE FUNCTION dbo.fn_saldo_vale
(
	@id_vale bigint
)
RETURNS int
AS
BEGIN
	RETURN (SELECT ISNULL(SUM(cantidad - cantidad_devuelta - cantidad_extraviada - cantidad_transferida), 0)
	          FROM dbo.detalle_vale
	         WHERE id_vale = @id_vale);
END
GO


-- ============================================================
-- 10. PROCEDIMIENTOS ALMACENADOS
-- En SQL Server una función no puede modificar datos; por eso los cálculos
-- fn_recalcular_comerciante y fn_recalcular_estado_vale del script PostgreSQL
-- se implementan como procedimientos con parámetro de salida.
-- ============================================================

-- 10.1 Estado del comerciante (RN-23) e índice de cumplimiento (RN-24)
CREATE PROCEDURE dbo.sp_recalcular_comerciante
	@id_comerciante bigint,
	@estado         varchar(12) = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @estado_actual varchar(12), @exigibles int, @a_tiempo int;

	SELECT @estado_actual = estado
	  FROM dbo.comerciante WITH (UPDLOCK, ROWLOCK)
	 WHERE id_comerciante = @id_comerciante;

	IF @estado_actual IS NULL
		RETURN;

	-- vales exigibles: finalizados o vencidos (los ANULADOS se excluyen, RN-24)
	SELECT @exigibles = COUNT(CASE WHEN v.estado IN ('CERRADO', 'OBSERVADO', 'VENCIDO') THEN 1 END),
	       @a_tiempo  = COUNT(CASE WHEN v.estado IN ('CERRADO', 'OBSERVADO')
	                                AND v.cerrado_fuera_plazo = 0
	                                AND ISNULL(x.con_extravio, 0) = 0 THEN 1 END)
	  FROM dbo.vale v
	 OUTER APPLY (SELECT MAX(CASE WHEN d.cantidad_extraviada > 0 THEN 1 ELSE 0 END) AS con_extravio
	                FROM dbo.detalle_vale d
	               WHERE d.id_vale = v.id_vale) x
	 WHERE v.id_comerciante = @id_comerciante;

	IF @estado_actual = 'INACTIVO'
		SET @estado = @estado_actual;
	ELSE
		SET @estado = CASE WHEN EXISTS (SELECT 1 FROM dbo.vale
		                                 WHERE id_comerciante = @id_comerciante
		                                   AND estado = 'VENCIDO')
		                   THEN 'RESTRINGIDO' ELSE 'HABILITADO' END;

	UPDATE dbo.comerciante
	   SET estado = @estado,
	       indice_cumplimiento = CASE WHEN @exigibles = 0 THEN NULL
	                                  ELSE ROUND(100.0 * @a_tiempo / @exigibles, 2) END
	 WHERE id_comerciante = @id_comerciante;
END
GO

-- 10.2 Regla de precedencia RN-16: el estado del vale se calcula, no se edita
CREATE PROCEDURE dbo.sp_recalcular_estado_vale
	@id_vale    bigint,
	@ocurrencia datetime2(0) = NULL,
	@estado     varchar(12)  = NULL OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @estado_actual varchar(12), @limite datetime2(0), @saldo int,
	        @atribuible bit, @movido bit;

	IF @ocurrencia IS NULL
		SET @ocurrencia = SYSDATETIME();

	SELECT @estado_actual = estado, @limite = fecha_limite
	  FROM dbo.vale WITH (UPDLOCK, ROWLOCK)
	 WHERE id_vale = @id_vale;

	IF @estado_actual IS NULL OR @estado_actual IN ('ANULADO', 'CERRADO', 'OBSERVADO')
	BEGIN
		SET @estado = @estado_actual;
		RETURN;
	END

	SET @saldo = dbo.fn_saldo_vale(@id_vale);

	SET @atribuible = CASE WHEN EXISTS (SELECT 1
	                                      FROM dbo.detalle_devolucion dd
	                                      JOIN dbo.detalle_vale d ON d.id_detalle = dd.id_detalle_vale
	                                     WHERE d.id_vale = @id_vale AND dd.condicion = 'NO_APTO')
	                         OR EXISTS (SELECT 1 FROM dbo.detalle_vale
	                                     WHERE id_vale = @id_vale AND cantidad_extraviada > 0)
	                       THEN 1 ELSE 0 END;

	SET @movido = CASE WHEN EXISTS (SELECT 1 FROM dbo.devolucion WHERE id_vale = @id_vale)
	                     OR EXISTS (SELECT 1 FROM dbo.detalle_vale
	                                 WHERE id_vale = @id_vale
	                                   AND cantidad_extraviada + cantidad_transferida > 0)
	                   THEN 1 ELSE 0 END;

	SET @estado = CASE
		WHEN @saldo = 0 AND @atribuible = 1 THEN 'OBSERVADO'
		WHEN @saldo = 0                     THEN 'CERRADO'
		WHEN @limite < @ocurrencia          THEN 'VENCIDO'
		WHEN @movido = 1                    THEN 'PARCIAL'
		ELSE @estado_actual END;             -- EMITIDO o VIGENTE se mantienen

	IF @estado <> @estado_actual
		UPDATE dbo.vale
		   SET estado = @estado,
		       fecha_cierre = CASE WHEN @estado IN ('CERRADO', 'OBSERVADO') THEN @ocurrencia END,
		       cerrado_fuera_plazo = CASE WHEN @estado IN ('CERRADO', 'OBSERVADO')
		                                   AND @ocurrencia > @limite THEN 1 ELSE 0 END   -- RN-19
		 WHERE id_vale = @id_vale;
END
GO

-- 10.3 Procedimiento principal: registrar préstamo y emitir el vale (CU-05)
--      @lineas: [{"id_tipo":1,"cantidad":20}, {"id_unidad":15}]
CREATE PROCEDURE dbo.sp_registrar_prestamo
	@id_comerciante bigint,
	@id_usuario     bigint,
	@lineas         nvarchar(max)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @msg nvarchar(400), @estado_com varchar(12), @id_mercado bigint, @rol varchar(15),
	        @mercado_usuario bigint, @codigo varchar(10), @plazo smallint,
	        @emision datetime2(0) = SYSDATETIME(), @limite datetime2(0), @anio smallint,
	        @corr int, @folio varchar(30), @id_vale bigint, @firma char(64),
	        @i int = 1, @n int, @t bigint, @cant int, @u bigint, @u_estado varchar(15),
	        @u_mercado bigint, @u_tipo bigint, @modo varchar(12), @cod_tipo varchar(20);
	DECLARE @l TABLE (n int IDENTITY(1,1) PRIMARY KEY, id_tipo bigint, cantidad int, id_unidad bigint);

	IF ISNULL(ISJSON(@lineas), 0) = 0 OR LEFT(LTRIM(@lineas), 1) <> '['
		THROW 50000, N'EV000: @lineas debe ser un arreglo JSON de líneas', 1;
	IF SESSION_CONTEXT(N'clave_hmac') IS NULL
		THROW 50000, N'EV000: falta la clave HMAC en el contexto de la sesión (sp_set_session_context ''clave_hmac'')', 1;

	INSERT INTO @l (id_tipo, cantidad, id_unidad)
	SELECT id_tipo, cantidad, id_unidad
	  FROM OPENJSON(@lineas)
	  WITH (id_tipo bigint '$.id_tipo', cantidad int '$.cantidad', id_unidad bigint '$.id_unidad');
	SET @n = @@ROWCOUNT;
	IF @n = 0
		THROW 50000, N'EV000: el préstamo requiere al menos una línea', 1;

	EXEC sys.sp_set_session_context @key = N'id_usuario', @value = @id_usuario;

	BEGIN TRY
		BEGIN TRANSACTION;

		-- (1) RD-04 / RF-15: la habilitación se verifica antes de tocar el inventario
		SELECT @estado_com = co.estado, @id_mercado = p.id_mercado
		  FROM dbo.comerciante co WITH (UPDLOCK, ROWLOCK)
		  JOIN dbo.puesto p ON p.id_puesto = co.id_puesto
		 WHERE co.id_comerciante = @id_comerciante;

		IF @id_mercado IS NULL
		BEGIN
			SET @msg = CONCAT(N'EV000: el comerciante ', @id_comerciante, N' no existe');
			THROW 50000, @msg, 1;
		END
		IF @estado_com <> 'HABILITADO'
		BEGIN
			SET @msg = CONCAT(N'EV001: el comerciante ', @id_comerciante, N' está ', @estado_com,
			                  N': tiene vales vencidos por regularizar (RD-04). No se aplica ningún cobro.');
			THROW 50001, @msg, 1;
		END

		SELECT @rol = rol, @mercado_usuario = id_mercado
		  FROM dbo.usuario
		 WHERE id_usuario = @id_usuario AND activo = 1;
		IF @rol IS NULL OR @rol = 'COMERCIANTE' OR (@rol = 'ENCARGADO' AND @mercado_usuario <> @id_mercado)
			THROW 50006, N'EV006: el usuario no opera el mercado del comerciante (RNF-11)', 1;

		SELECT @codigo = codigo, @plazo = plazo_vale_dias
		  FROM dbo.mercado
		 WHERE id_mercado = @id_mercado;
		SET @limite = DATEADD(DAY, @plazo, @emision);                   -- RD-03
		SET @anio = YEAR(@emision);

		-- (2) RD-02: folio correlativo irrepetible por mercado y año (fila bloqueada)
		UPDATE dbo.serie_folio WITH (UPDLOCK, HOLDLOCK)
		   SET @corr = ultimo_correlativo = ultimo_correlativo + 1
		 WHERE id_mercado = @id_mercado AND anio = @anio;
		IF @@ROWCOUNT = 0
		BEGIN
			INSERT INTO dbo.serie_folio (id_mercado, anio, ultimo_correlativo)
			VALUES (@id_mercado, @anio, 1);
			SET @corr = 1;
		END
		SET @folio = CONCAT('VAL-', @codigo, '-', @anio, '-', RIGHT(CONCAT('000000', @corr), 6));

		INSERT INTO dbo.vale (folio, id_mercado, id_comerciante, id_usuario_emisor, fecha_emision, fecha_limite)
		VALUES (@folio, @id_mercado, @id_comerciante, @id_usuario, @emision, @limite);
		SET @id_vale = SCOPE_IDENTITY();

		-- (3) líneas: RF-16, RN-06 y RN-10 con bloqueo del stock
		WHILE @i <= @n
		BEGIN
			SELECT @t = id_tipo, @cant = cantidad, @u = id_unidad FROM @l WHERE n = @i;

			IF @u IS NOT NULL
			BEGIN
				SELECT @u_estado = NULL, @u_mercado = NULL, @u_tipo = NULL;
				SELECT @u_estado = estado, @u_mercado = id_mercado, @u_tipo = id_tipo
				  FROM dbo.envase_unidad WITH (UPDLOCK, ROWLOCK)
				 WHERE id_unidad = @u;
				IF @u_estado IS NULL OR @u_estado <> 'DISPONIBLE' OR @u_mercado <> @id_mercado
				BEGIN
					SET @msg = CONCAT(N'EV003: la unidad ', @u, N' no está disponible en el mercado (RN-06)');
					THROW 50003, @msg, 1;
				END
				INSERT INTO dbo.detalle_vale (id_vale, id_tipo, id_unidad, cantidad)
				VALUES (@id_vale, @u_tipo, @u, 1);
				UPDATE dbo.envase_unidad SET estado = 'PRESTADO' WHERE id_unidad = @u;
			END
			ELSE
			BEGIN
				SELECT @modo = NULL, @cod_tipo = NULL;
				SELECT @modo = modo_identificacion, @cod_tipo = codigo
				  FROM dbo.tipo_envase
				 WHERE id_tipo = @t AND activo = 1;
				IF @modo IS NULL OR @modo <> 'POR_CANTIDAD'
				BEGIN
					SET @msg = CONCAT(N'EV003: el tipo ', ISNULL(@cod_tipo, CONCAT('', @t)),
					                  N' no existe o exige escanear cada unidad (RN-02)');
					THROW 50003, @msg, 1;
				END
				IF @cant IS NULL OR @cant <= 0
					THROW 50000, N'EV000: la cantidad de cada línea debe ser mayor que cero', 1;

				UPDATE dbo.inventario_mercado
				   SET cant_disponible = cant_disponible - @cant,
				       cant_prestada   = cant_prestada + @cant,
				       actualizado_en  = SYSDATETIME()
				 WHERE id_mercado = @id_mercado AND id_tipo = @t AND cant_disponible >= @cant;
				IF @@ROWCOUNT = 0
				BEGIN
					SET @msg = CONCAT(N'EV002: stock insuficiente de ', @cod_tipo, N' para prestar ', @cant, N' (RF-16)');
					THROW 50002, @msg, 1;
				END
				INSERT INTO dbo.detalle_vale (id_vale, id_tipo, cantidad)
				VALUES (@id_vale, @t, @cant);
			END
			SET @i += 1;
		END

		-- (4) RNF-09: firma del QR; el trigger de auditoría registra los eventos
		SET @firma = dbo.fn_firmar_vale(@folio, @emision, @limite);
		UPDATE dbo.vale SET firma_qr = @firma WHERE id_vale = @id_vale;

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH;

	SELECT id_vale, folio, fecha_limite, firma_qr
	  FROM dbo.vale
	 WHERE id_vale = @id_vale;
END
GO

-- 10.4 T-02: el encargado confirma la entrega física (EMITIDO -> VIGENTE)
CREATE PROCEDURE dbo.sp_confirmar_entrega
	@id_vale    bigint,
	@id_usuario bigint
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @msg nvarchar(200), @estado varchar(12);

	EXEC sys.sp_set_session_context @key = N'id_usuario', @value = @id_usuario;

	BEGIN TRY
		BEGIN TRANSACTION;
		SELECT @estado = estado FROM dbo.vale WITH (UPDLOCK, ROWLOCK) WHERE id_vale = @id_vale;
		IF @estado IS NULL OR @estado <> 'EMITIDO'
		BEGIN
			SET @msg = CONCAT(N'EV005: el vale ', @id_vale, N' no está EMITIDO');
			THROW 50005, @msg, 1;
		END
		UPDATE dbo.vale SET estado = 'VIGENTE' WHERE id_vale = @id_vale;
		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH;

	SELECT 'VIGENTE' AS estado_tras_entrega;
END
GO

-- 10.5 Procedimiento principal: registrar devolución (CU-07)
--      @lineas: [{"id_detalle":10,"cantidad":12,"condicion":"APTO"},
--                {"id_detalle":10,"cantidad":2,"condicion":"NO_APTO","tipo":"DANO",
--                 "url_evidencia":"https://.../foto.jpg"},
--                {"id_unidad":15,"condicion":"APTO"}]
CREATE PROCEDURE dbo.sp_registrar_devolucion
	@id_vale      bigint,
	@id_usuario   bigint,
	@lineas       nvarchar(max),
	@observacion  varchar(500)     = NULL,
	@ocurrencia   datetime2(0)     = NULL,
	@id_operacion uniqueidentifier = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @msg nvarchar(400), @estado_vale varchar(12), @id_mercado bigint, @id_comerciante bigint,
	        @id_dev bigint, @id_det_dev bigint, @i int = 1, @n int,
	        @det bigint, @u bigint, @cant int, @cond varchar(20), @tipo varchar(15),
	        @desc varchar(500), @url varchar(300),
	        @id_det bigint, @d_tipo bigint, @d_unidad bigint, @saldo_linea int, @vida int,
	        @estado_res varchar(12), @estado_com varchar(12);
	DECLARE @l TABLE (n int IDENTITY(1,1) PRIMARY KEY, id_detalle bigint, id_unidad bigint, cantidad int,
	                  condicion varchar(20), tipo varchar(15), descripcion varchar(500), url_evidencia varchar(300));

	IF ISNULL(ISJSON(@lineas), 0) = 0 OR LEFT(LTRIM(@lineas), 1) <> '['
		THROW 50000, N'EV000: @lineas debe ser un arreglo JSON de líneas', 1;
	IF @ocurrencia IS NULL
		SET @ocurrencia = SYSDATETIME();

	INSERT INTO @l (id_detalle, id_unidad, cantidad, condicion, tipo, descripcion, url_evidencia)
	SELECT id_detalle, id_unidad, cantidad, condicion, tipo, descripcion, url_evidencia
	  FROM OPENJSON(@lineas)
	  WITH (id_detalle    bigint       '$.id_detalle',
	        id_unidad     bigint       '$.id_unidad',
	        cantidad      int          '$.cantidad',
	        condicion     varchar(20)  '$.condicion',
	        tipo          varchar(15)  '$.tipo',
	        descripcion   varchar(500) '$.descripcion',
	        url_evidencia varchar(300) '$.url_evidencia');
	SET @n = @@ROWCOUNT;
	IF @n = 0
		THROW 50000, N'EV000: la devolución requiere al menos una línea', 1;

	EXEC sys.sp_set_session_context @key = N'id_usuario', @value = @id_usuario;

	BEGIN TRY
		BEGIN TRANSACTION;

		SELECT @estado_vale = estado, @id_mercado = id_mercado, @id_comerciante = id_comerciante
		  FROM dbo.vale WITH (UPDLOCK, ROWLOCK)
		 WHERE id_vale = @id_vale;
		IF @estado_vale IS NULL OR @estado_vale NOT IN ('VIGENTE', 'PARCIAL', 'VENCIDO')   -- RN-20
		BEGIN
			SET @msg = CONCAT(N'EV005: el vale ', @id_vale, N' no admite devoluciones (estado ',
			                  ISNULL(@estado_vale, N'inexistente'), N')');
			THROW 50005, @msg, 1;
		END

		INSERT INTO dbo.devolucion (id_vale, id_usuario_receptor, fecha_hora, observacion, origen_offline, id_operacion)
		VALUES (@id_vale, @id_usuario, @ocurrencia, @observacion,
		        CASE WHEN @id_operacion IS NULL THEN 0 ELSE 1 END, @id_operacion);
		SET @id_dev = SCOPE_IDENTITY();

		WHILE @i <= @n
		BEGIN
			SELECT @det = id_detalle, @u = id_unidad, @cant = cantidad, @cond = condicion,
			       @tipo = tipo, @desc = descripcion, @url = url_evidencia
			  FROM @l WHERE n = @i;
			IF @cond IS NULL OR @cond NOT IN ('APTO', 'REQUIERE_REVISION', 'NO_APTO')
				THROW 50000, N'EV000: condición no válida (APTO, REQUIERE_REVISION o NO_APTO)', 1;
			IF @cond = 'NO_APTO' AND ISNULL(@tipo, 'DANO') NOT IN ('DANO', 'CONTAMINACION', 'EXTRAVIO')
				THROW 50000, N'EV000: tipo de incidencia no válido (DANO, CONTAMINACION o EXTRAVIO)', 1;
			IF @cond = 'NO_APTO' AND ISNULL(@tipo, 'DANO') <> 'EXTRAVIO' AND @url IS NULL
				THROW 50000, N'EV000: un envase NO APTO exige la foto de evidencia (RN-12)', 1;

			SELECT @id_det = NULL, @d_tipo = NULL, @d_unidad = NULL, @saldo_linea = NULL;
			IF @u IS NOT NULL                                             -- RN-07
			BEGIN
				SELECT TOP (1) @id_det = id_detalle, @d_tipo = id_tipo, @d_unidad = id_unidad
				  FROM dbo.detalle_vale WITH (UPDLOCK, ROWLOCK)
				 WHERE id_vale = @id_vale AND id_unidad = @u
				   AND cantidad_devuelta + cantidad_extraviada + cantidad_transferida < cantidad;
				IF @id_det IS NULL
				BEGIN
					SET @msg = CONCAT(N'EV004: la unidad ', @u, N' no tiene saldo en el vale (RD-06)');
					THROW 50004, @msg, 1;
				END
				SET @cant = 1;
			END
			ELSE                                                          -- RN-11
			BEGIN
				SELECT @id_det = id_detalle, @d_tipo = id_tipo, @d_unidad = id_unidad,
				       @saldo_linea = cantidad - cantidad_devuelta - cantidad_extraviada - cantidad_transferida
				  FROM dbo.detalle_vale WITH (UPDLOCK, ROWLOCK)
				 WHERE id_detalle = @det AND id_vale = @id_vale;
				IF @id_det IS NULL OR @cant IS NULL OR @cant <= 0 OR @cant > @saldo_linea
					THROW 50004, N'EV004: la cantidad devuelta supera el saldo pendiente (RD-05)', 1;
			END

			-- el trigger trg_det_dev_acumular suma la cantidad devuelta a la línea
			INSERT INTO dbo.detalle_devolucion (id_devolucion, id_detalle_vale, cantidad, condicion)
			VALUES (@id_dev, @id_det, @cant, @cond);
			SET @id_det_dev = SCOPE_IDENTITY();

			IF @cond = 'NO_APTO'                                          -- RN-08 / RN-12
				INSERT INTO dbo.incidencia (id_vale, id_det_dev, id_detalle_vale, id_unidad, tipo,
				                            descripcion, url_evidencia, cantidad_afectada,
				                            id_usuario_registra, fecha_hora)
				VALUES (@id_vale, @id_det_dev, @id_det, @d_unidad, ISNULL(@tipo, 'DANO'),
				        ISNULL(@desc, 'Envase NO APTO en la recepción'), @url, @cant,
				        @id_usuario, @ocurrencia);

			SELECT @vida = vida_util_ciclos FROM dbo.tipo_envase WHERE id_tipo = @d_tipo;

			IF @d_unidad IS NOT NULL                                      -- RN-08
				UPDATE dbo.envase_unidad
				   SET estado = CASE @cond
				                  WHEN 'APTO' THEN CASE WHEN ciclos_realizados + 1 >= @vida
				                                        THEN 'EN_REVISION' ELSE 'DISPONIBLE' END
				                  WHEN 'REQUIERE_REVISION' THEN 'EN_REVISION'
				                  ELSE 'DADO_DE_BAJA' END,
				       ciclos_realizados = ciclos_realizados + CASE WHEN @cond = 'APTO' THEN 1 ELSE 0 END,
				       causa_baja = CASE WHEN @cond = 'NO_APTO' THEN ISNULL(@tipo, 'DANO') END
				 WHERE id_unidad = @d_unidad;
			ELSE                                                          -- RN-12
				UPDATE dbo.inventario_mercado
				   SET cant_prestada   = cant_prestada - @cant,
				       cant_disponible = cant_disponible + CASE WHEN @cond = 'APTO' THEN @cant ELSE 0 END,
				       cant_revision   = cant_revision + CASE WHEN @cond = 'REQUIERE_REVISION' THEN @cant ELSE 0 END,
				       cant_baja       = cant_baja + CASE WHEN @cond = 'NO_APTO' THEN @cant ELSE 0 END,
				       actualizado_en  = SYSDATETIME()
				 WHERE id_mercado = @id_mercado AND id_tipo = @d_tipo;

			SET @i += 1;
		END

		EXEC dbo.sp_recalcular_estado_vale @id_vale = @id_vale, @ocurrencia = @ocurrencia,
		                                   @estado = @estado_res OUTPUT;          -- RN-16
		EXEC dbo.sp_recalcular_comerciante @id_comerciante = @id_comerciante,
		                                   @estado = @estado_com OUTPUT;          -- RN-23
		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH;

	SELECT @id_dev AS id_devolucion, @estado_res AS estado_resultante,
	       dbo.fn_saldo_vale(@id_vale) AS saldo, @estado_com AS estado_del_comerciante;
END
GO

-- 10.6 Proceso programado de las 00:05 (RF-29, CU-13): vence vales y restringe comerciantes
CREATE PROCEDURE dbo.sp_vencer_vales
	@corte datetime2(0) = NULL
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @vencidos TABLE (id_comerciante bigint);
	DECLARE @total int, @id bigint;

	IF @corte IS NULL
		SET @corte = SYSDATETIME();
	EXEC sys.sp_set_session_context @key = N'dispositivo', @value = N'worker-00:05';

	BEGIN TRY
		BEGIN TRANSACTION;

		UPDATE dbo.vale
		   SET estado = 'VENCIDO'
		OUTPUT inserted.id_comerciante INTO @vencidos (id_comerciante)
		 WHERE estado IN ('VIGENTE', 'PARCIAL') AND fecha_limite < @corte;

		SELECT @total = COUNT(*) FROM @vencidos;

		DECLARE c_comerciantes CURSOR LOCAL FAST_FORWARD FOR
			SELECT DISTINCT id_comerciante FROM @vencidos;
		OPEN c_comerciantes;
		FETCH NEXT FROM c_comerciantes INTO @id;
		WHILE @@FETCH_STATUS = 0
		BEGIN
			EXEC dbo.sp_recalcular_comerciante @id_comerciante = @id;      -- RD-04
			FETCH NEXT FROM c_comerciantes INTO @id;
		END
		CLOSE c_comerciantes;
		DEALLOCATE c_comerciantes;

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH;

	EXEC sys.sp_set_session_context @key = N'dispositivo', @value = NULL;
	SELECT @total AS vales_vencidos;
	RETURN @total;
END
GO

-- 10.7 Anulación de un vale (RF-20, RN-21)
CREATE PROCEDURE dbo.sp_anular_vale
	@id_vale  bigint,
	@id_admin bigint,
	@motivo   varchar(500)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @msg nvarchar(300), @estado varchar(12), @folio varchar(30),
	        @id_mercado bigint, @id_comerciante bigint;

	EXEC sys.sp_set_session_context @key = N'id_usuario', @value = @id_admin;

	IF NOT EXISTS (SELECT 1 FROM dbo.usuario
	                WHERE id_usuario = @id_admin AND rol = 'ADMINISTRADOR' AND activo = 1)
		THROW 50006, N'EV006: solo el Administrador anula vales (RF-20)', 1;
	IF LEN(LTRIM(RTRIM(ISNULL(@motivo, '')))) = 0
		THROW 50000, N'EV000: la anulación exige un motivo', 1;

	BEGIN TRY
		BEGIN TRANSACTION;

		SELECT @estado = estado, @folio = folio, @id_mercado = id_mercado, @id_comerciante = id_comerciante
		  FROM dbo.vale WITH (UPDLOCK, ROWLOCK)
		 WHERE id_vale = @id_vale;

		IF @estado IS NULL OR @estado NOT IN ('EMITIDO', 'VIGENTE', 'VENCIDO')
		   OR EXISTS (SELECT 1 FROM dbo.devolucion WHERE id_vale = @id_vale)
		   OR EXISTS (SELECT 1 FROM dbo.incidencia WHERE id_vale = @id_vale)
		BEGIN
			SET @msg = CONCAT(N'EV005: el vale ', ISNULL(@folio, CONCAT('', @id_vale)), N' no puede anularse (RN-21)');
			THROW 50005, @msg, 1;
		END

		-- restituye el inventario: unidades a DISPONIBLE y cantidades al saldo disponible
		UPDATE u
		   SET estado = 'DISPONIBLE'
		  FROM dbo.envase_unidad u
		  JOIN dbo.detalle_vale d ON d.id_unidad = u.id_unidad
		 WHERE d.id_vale = @id_vale;

		UPDATE i
		   SET cant_prestada   = i.cant_prestada - x.total,
		       cant_disponible = i.cant_disponible + x.total,
		       actualizado_en  = SYSDATETIME()
		  FROM dbo.inventario_mercado i
		  JOIN (SELECT id_tipo, SUM(cantidad) AS total
		          FROM dbo.detalle_vale
		         WHERE id_vale = @id_vale AND id_unidad IS NULL
		         GROUP BY id_tipo) x ON x.id_tipo = i.id_tipo
		 WHERE i.id_mercado = @id_mercado;

		-- los envases vuelven al almacén: las líneas quedan sin saldo pendiente, lo que
		-- libera las unidades en la vista indexada v_unidad_con_saldo (RN-06). Los vales
		-- ANULADOS se excluyen de los indicadores (RN-24), por lo que no alteran la tasa de retorno.
		UPDATE dbo.detalle_vale
		   SET cantidad_devuelta = cantidad - cantidad_extraviada - cantidad_transferida
		 WHERE id_vale = @id_vale;

		UPDATE dbo.vale
		   SET estado = 'ANULADO', motivo_anulacion = @motivo
		 WHERE id_vale = @id_vale;

		EXEC dbo.sp_recalcular_comerciante @id_comerciante = @id_comerciante;
		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH;

	SELECT 'ANULADO' AS estado;
END
GO


-- ============================================================
-- 11. TRIGGERS
-- ============================================================

-- 11.1 RD-08: la bitácora es de solo inserción. TRUNCATE no dispara triggers en
--      SQL Server; se impide porque ningún rol de la sección 13 tiene permiso ALTER.
CREATE TRIGGER dbo.trg_bitacora_inmutable
ON dbo.bitacora
INSTEAD OF UPDATE, DELETE
AS
BEGIN
	SET NOCOUNT ON;
	THROW 50006, N'EV006: la bitácora es de solo inserción (RD-08): operación rechazada', 1;
END
GO

-- 11.2 RD-08: los registros operativos se anulan, nunca se eliminan
CREATE TRIGGER dbo.trg_vale_sin_delete
ON dbo.vale
INSTEAD OF DELETE
AS
BEGIN
	SET NOCOUNT ON;
	THROW 50006, N'EV006: no se permite eliminar registros de vale (RD-08); use la anulación', 1;
END
GO

CREATE TRIGGER dbo.trg_detalle_vale_sin_delete
ON dbo.detalle_vale
INSTEAD OF DELETE
AS
BEGIN
	SET NOCOUNT ON;
	THROW 50006, N'EV006: no se permite eliminar registros de detalle_vale (RD-08)', 1;
END
GO

CREATE TRIGGER dbo.trg_devolucion_sin_delete
ON dbo.devolucion
INSTEAD OF DELETE
AS
BEGIN
	SET NOCOUNT ON;
	THROW 50006, N'EV006: no se permite eliminar registros de devolucion (RD-08)', 1;
END
GO

CREATE TRIGGER dbo.trg_det_dev_sin_delete
ON dbo.detalle_devolucion
INSTEAD OF DELETE
AS
BEGIN
	SET NOCOUNT ON;
	THROW 50006, N'EV006: no se permite eliminar registros de detalle_devolucion (RD-08)', 1;
END
GO

CREATE TRIGGER dbo.trg_incidencia_sin_delete
ON dbo.incidencia
INSTEAD OF DELETE
AS
BEGIN
	SET NOCOUNT ON;
	THROW 50006, N'EV006: no se permite eliminar registros de incidencia (RD-08)', 1;
END
GO

-- 11.3 RN-02: cada línea respeta la modalidad de su tipo de envase
CREATE TRIGGER dbo.trg_detalle_vale_modalidad
ON dbo.detalle_vale
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
	IF EXISTS (SELECT 1
	             FROM inserted i
	             JOIN dbo.tipo_envase t ON t.id_tipo = i.id_tipo
	             LEFT JOIN dbo.envase_unidad u ON u.id_unidad = i.id_unidad
	            WHERE (t.modo_identificacion = 'POR_UNIDAD'
	                   AND (i.id_unidad IS NULL OR u.id_tipo <> i.id_tipo))
	               OR (t.modo_identificacion = 'POR_CANTIDAD' AND i.id_unidad IS NOT NULL))
		THROW 50003, N'EV003: la línea no respeta la modalidad del tipo de envase (RN-02)', 1;
END
GO

-- 11.4 RD-05 / RD-06: cada línea devuelta descuenta el saldo; la restricción
--      ck_detalle_saldo rechaza cualquier exceso o doble registro
CREATE TRIGGER dbo.trg_det_dev_acumular
ON dbo.detalle_devolucion
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
	UPDATE d
	   SET cantidad_devuelta = d.cantidad_devuelta + x.total
	  FROM dbo.detalle_vale d
	  JOIN (SELECT id_detalle_vale, SUM(cantidad) AS total
	          FROM inserted
	         GROUP BY id_detalle_vale) x ON x.id_detalle_vale = d.id_detalle;
END
GO

-- 11.5 RF-36: auditoría automática (quién, qué, cuándo, desde dónde).
--      El usuario y el dispositivo los fija la API con sp_set_session_context.
CREATE TRIGGER dbo.trg_auditar_vale
ON dbo.vale
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO dbo.bitacora (id_usuario, entidad, id_entidad, accion, valor_anterior, valor_nuevo, dispositivo, ip)
	SELECT CAST(SESSION_CONTEXT(N'id_usuario') AS bigint), 'vale', CAST(i.id_vale AS varchar(40)),
	       CASE WHEN d.id_vale IS NULL THEN 'CREAR'
	            WHEN i.estado = 'ANULADO' AND d.estado <> 'ANULADO' THEN 'ANULAR'
	            ELSE 'MODIFICAR' END,
	       ant.json, nue.json,
	       CAST(SESSION_CONTEXT(N'dispositivo') AS varchar(80)),
	       CAST(CONNECTIONPROPERTY('client_net_address') AS varchar(45))
	  FROM inserted i
	  LEFT JOIN deleted d ON d.id_vale = i.id_vale
	 CROSS APPLY (SELECT (SELECT x.* FROM inserted x WHERE x.id_vale = i.id_vale
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) nue
	 OUTER APPLY (SELECT (SELECT y.* FROM deleted y WHERE y.id_vale = i.id_vale
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) ant
	 WHERE d.id_vale IS NULL OR ISNULL(ant.json, N'') <> ISNULL(nue.json, N'');
END
GO

CREATE TRIGGER dbo.trg_auditar_devolucion
ON dbo.devolucion
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO dbo.bitacora (id_usuario, entidad, id_entidad, accion, valor_anterior, valor_nuevo, dispositivo, ip)
	SELECT CAST(SESSION_CONTEXT(N'id_usuario') AS bigint), 'devolucion', CAST(i.id_devolucion AS varchar(40)),
	       'CREAR', NULL, nue.json,
	       CAST(SESSION_CONTEXT(N'dispositivo') AS varchar(80)),
	       CAST(CONNECTIONPROPERTY('client_net_address') AS varchar(45))
	  FROM inserted i
	 CROSS APPLY (SELECT (SELECT x.* FROM inserted x WHERE x.id_devolucion = i.id_devolucion
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) nue;
END
GO

CREATE TRIGGER dbo.trg_auditar_incidencia
ON dbo.incidencia
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO dbo.bitacora (id_usuario, entidad, id_entidad, accion, valor_anterior, valor_nuevo, dispositivo, ip)
	SELECT CAST(SESSION_CONTEXT(N'id_usuario') AS bigint), 'incidencia', CAST(i.id_incidencia AS varchar(40)),
	       CASE WHEN d.id_incidencia IS NULL THEN 'CREAR'
	            WHEN i.estado_incidencia = 'VALIDADA' AND d.estado_incidencia <> 'VALIDADA' THEN 'VALIDAR'
	            ELSE 'MODIFICAR' END,
	       ant.json, nue.json,
	       CAST(SESSION_CONTEXT(N'dispositivo') AS varchar(80)),
	       CAST(CONNECTIONPROPERTY('client_net_address') AS varchar(45))
	  FROM inserted i
	  LEFT JOIN deleted d ON d.id_incidencia = i.id_incidencia
	 CROSS APPLY (SELECT (SELECT x.* FROM inserted x WHERE x.id_incidencia = i.id_incidencia
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) nue
	 OUTER APPLY (SELECT (SELECT y.* FROM deleted y WHERE y.id_incidencia = i.id_incidencia
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) ant
	 WHERE d.id_incidencia IS NULL OR ISNULL(ant.json, N'') <> ISNULL(nue.json, N'');
END
GO

CREATE TRIGGER dbo.trg_auditar_comerciante
ON dbo.comerciante
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO dbo.bitacora (id_usuario, entidad, id_entidad, accion, valor_anterior, valor_nuevo, dispositivo, ip)
	SELECT CAST(SESSION_CONTEXT(N'id_usuario') AS bigint), 'comerciante', CAST(i.id_comerciante AS varchar(40)),
	       CASE WHEN d.id_comerciante IS NULL THEN 'CREAR' ELSE 'MODIFICAR' END,
	       ant.json, nue.json,
	       CAST(SESSION_CONTEXT(N'dispositivo') AS varchar(80)),
	       CAST(CONNECTIONPROPERTY('client_net_address') AS varchar(45))
	  FROM inserted i
	  LEFT JOIN deleted d ON d.id_comerciante = i.id_comerciante
	 CROSS APPLY (SELECT (SELECT x.* FROM inserted x WHERE x.id_comerciante = i.id_comerciante
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) nue
	 OUTER APPLY (SELECT (SELECT y.* FROM deleted y WHERE y.id_comerciante = i.id_comerciante
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) ant
	 WHERE d.id_comerciante IS NULL OR ISNULL(ant.json, N'') <> ISNULL(nue.json, N'');
END
GO

-- usuario: se excluye el hash de la contraseña del registro de auditoría
CREATE TRIGGER dbo.trg_auditar_usuario
ON dbo.usuario
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO dbo.bitacora (id_usuario, entidad, id_entidad, accion, valor_anterior, valor_nuevo, dispositivo, ip)
	SELECT CAST(SESSION_CONTEXT(N'id_usuario') AS bigint), 'usuario', CAST(i.id_usuario AS varchar(40)),
	       CASE WHEN d.id_usuario IS NULL THEN 'CREAR' ELSE 'MODIFICAR' END,
	       ant.json, nue.json,
	       CAST(SESSION_CONTEXT(N'dispositivo') AS varchar(80)),
	       CAST(CONNECTIONPROPERTY('client_net_address') AS varchar(45))
	  FROM inserted i
	  LEFT JOIN deleted d ON d.id_usuario = i.id_usuario
	 CROSS APPLY (SELECT (SELECT x.id_usuario, x.id_mercado, x.nombre_usuario, x.rol, x.intentos_fallidos,
	                             x.bloqueado_hasta, x.activo, x.creado_en
	                        FROM inserted x WHERE x.id_usuario = i.id_usuario
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) nue
	 OUTER APPLY (SELECT (SELECT y.id_usuario, y.id_mercado, y.nombre_usuario, y.rol, y.intentos_fallidos,
	                             y.bloqueado_hasta, y.activo, y.creado_en
	                        FROM deleted y WHERE y.id_usuario = i.id_usuario
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) ant
	 WHERE d.id_usuario IS NULL OR ISNULL(ant.json, N'') <> ISNULL(nue.json, N'');
END
GO

CREATE TRIGGER dbo.trg_auditar_tipo_envase
ON dbo.tipo_envase
AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO dbo.bitacora (id_usuario, entidad, id_entidad, accion, valor_anterior, valor_nuevo, dispositivo, ip)
	SELECT CAST(SESSION_CONTEXT(N'id_usuario') AS bigint), 'tipo_envase', CAST(i.id_tipo AS varchar(40)),
	       CASE WHEN d.id_tipo IS NULL THEN 'CREAR' ELSE 'MODIFICAR' END,
	       ant.json, nue.json,
	       CAST(SESSION_CONTEXT(N'dispositivo') AS varchar(80)),
	       CAST(CONNECTIONPROPERTY('client_net_address') AS varchar(45))
	  FROM inserted i
	  LEFT JOIN deleted d ON d.id_tipo = i.id_tipo
	 CROSS APPLY (SELECT (SELECT x.* FROM inserted x WHERE x.id_tipo = i.id_tipo
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) nue
	 OUTER APPLY (SELECT (SELECT y.* FROM deleted y WHERE y.id_tipo = i.id_tipo
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) ant
	 WHERE d.id_tipo IS NULL OR ISNULL(ant.json, N'') <> ISNULL(nue.json, N'');
END
GO

CREATE TRIGGER dbo.trg_auditar_ajuste
ON dbo.ajuste_inventario
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;
	INSERT INTO dbo.bitacora (id_usuario, entidad, id_entidad, accion, valor_anterior, valor_nuevo, dispositivo, ip)
	SELECT CAST(SESSION_CONTEXT(N'id_usuario') AS bigint), 'ajuste_inventario', CAST(i.id_ajuste AS varchar(40)),
	       'AJUSTAR', NULL, nue.json,
	       CAST(SESSION_CONTEXT(N'dispositivo') AS varchar(80)),
	       CAST(CONNECTIONPROPERTY('client_net_address') AS varchar(45))
	  FROM inserted i
	 CROSS APPLY (SELECT (SELECT x.* FROM inserted x WHERE x.id_ajuste = i.id_ajuste
	                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES) AS json) nue;
END
GO


-- ============================================================
-- 12. VISTAS
-- ============================================================

-- 12.1 RF-12: inventario por mercado y estado (ambas modalidades, RN-03)
CREATE VIEW dbo.v_inventario_mercado
AS
SELECT i.id_mercado, t.codigo AS tipo, t.modo_identificacion,
       i.cant_disponible AS disponible, i.cant_prestada AS prestado,
       i.cant_revision AS en_revision, i.cant_baja AS dado_de_baja,
       i.cant_disponible + i.cant_prestada + i.cant_revision + i.cant_baja AS total
  FROM dbo.inventario_mercado i
  JOIN dbo.tipo_envase t ON t.id_tipo = i.id_tipo
 WHERE t.modo_identificacion = 'POR_CANTIDAD'
UNION ALL
SELECT u.id_mercado, t.codigo, t.modo_identificacion,
       SUM(CASE WHEN u.estado = 'DISPONIBLE'   THEN 1 ELSE 0 END),
       SUM(CASE WHEN u.estado = 'PRESTADO'     THEN 1 ELSE 0 END),
       SUM(CASE WHEN u.estado = 'EN_REVISION'  THEN 1 ELSE 0 END),
       SUM(CASE WHEN u.estado = 'DADO_DE_BAJA' THEN 1 ELSE 0 END),
       COUNT(*)
  FROM dbo.envase_unidad u
  JOIN dbo.tipo_envase t ON t.id_tipo = u.id_tipo
 GROUP BY u.id_mercado, t.codigo, t.modo_identificacion
GO

-- 12.2 RF-31 / CU-09: vales con saldo pendiente, plazo y atraso
CREATE VIEW dbo.v_vales_pendientes
AS
SELECT v.id_mercado, v.id_vale, v.folio, v.estado, v.fecha_emision, v.fecha_limite,
       c.id_comerciante, c.nombres, p.codigo AS puesto, t.codigo AS tipo,
       d.cantidad - d.cantidad_devuelta - d.cantidad_extraviada - d.cantidad_transferida AS pendiente,
       CASE WHEN DATEDIFF(DAY, v.fecha_limite, SYSDATETIME()) > 0
            THEN DATEDIFF(DAY, v.fecha_limite, SYSDATETIME()) ELSE 0 END AS dias_atraso
  FROM dbo.vale v
  JOIN dbo.comerciante c  ON c.id_comerciante = v.id_comerciante
  JOIN dbo.puesto p       ON p.id_puesto = c.id_puesto
  JOIN dbo.detalle_vale d ON d.id_vale = v.id_vale
  JOIN dbo.tipo_envase t  ON t.id_tipo = d.id_tipo
 WHERE v.estado IN ('VIGENTE', 'PARCIAL', 'VENCIDO')
   AND d.cantidad > d.cantidad_devuelta + d.cantidad_extraviada + d.cantidad_transferida
GO

-- 12.3 RF-33: indicadores mensuales por mercado (tablero ODS 12).
--      SQL Server no tiene vistas materializadas con COUNT DISTINCT ni AVG; se usa
--      la vista de cálculo, una tabla de resultados y un procedimiento de refresco
--      que el proceso de las 00:05 ejecuta cada noche.
CREATE VIEW dbo.v_indicadores_mensuales
AS
SELECT v.id_mercado,
       DATEFROMPARTS(YEAR(v.fecha_emision), MONTH(v.fecha_emision), 1) AS mes,
       COUNT(*)                                                     AS vales_emitidos,
       SUM(d.prestados)                                             AS envases_prestados,
       SUM(d.devueltos)                                             AS envases_devueltos,
       CAST(ROUND(100.0 * SUM(d.devueltos)
                  / NULLIF(SUM(d.prestados - d.transferidos), 0), 2) AS decimal(6,2)) AS tasa_retorno,  -- RD-07
       CAST(ROUND(AVG(CASE WHEN v.fecha_cierre IS NOT NULL
                           THEN DATEDIFF(SECOND, v.fecha_emision, v.fecha_cierre) / 86400.0 END), 2)
            AS decimal(8,2))                                        AS ciclo_promedio_dias,
       SUM(CASE WHEN v.estado = 'VENCIDO' THEN 1 ELSE 0 END)        AS vales_vencidos,
       SUM(d.extraviados)                                           AS bajas_extravio
  FROM dbo.vale v
  JOIN (SELECT id_vale,
               SUM(cantidad)             AS prestados,
               SUM(cantidad_devuelta)    AS devueltos,
               SUM(cantidad_transferida) AS transferidos,
               SUM(cantidad_extraviada)  AS extraviados
          FROM dbo.detalle_vale
         GROUP BY id_vale) d ON d.id_vale = v.id_vale
 WHERE v.estado <> 'ANULADO'
 GROUP BY v.id_mercado, DATEFROMPARTS(YEAR(v.fecha_emision), MONTH(v.fecha_emision), 1)
GO

CREATE TABLE mv_indicadores_mensuales
(
	id_mercado           bigint        NOT NULL,
	mes                  date          NOT NULL,
	vales_emitidos       int           NOT NULL,
	envases_prestados    int           NOT NULL,
	envases_devueltos    int           NOT NULL,
	tasa_retorno         decimal(6,2)  NULL,
	ciclo_promedio_dias  decimal(8,2)  NULL,
	vales_vencidos       int           NOT NULL,
	bajas_extravio       int           NOT NULL,
	actualizado_en       datetime2(0)  NOT NULL,
	CONSTRAINT XPKmv_indicadores_mensuales PRIMARY KEY (id_mercado ASC, mes ASC),   -- ux_mv_indicadores
	CONSTRAINT R_42 FOREIGN KEY (id_mercado)
		REFERENCES mercado (id_mercado)
		ON DELETE NO ACTION
		ON UPDATE NO ACTION
)
GO

CREATE PROCEDURE dbo.sp_refrescar_indicadores
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	BEGIN TRANSACTION;          -- los lectores ven la versión anterior o la nueva, nunca una mezcla
		DELETE FROM dbo.mv_indicadores_mensuales;
		INSERT INTO dbo.mv_indicadores_mensuales (id_mercado, mes, vales_emitidos, envases_prestados,
		            envases_devueltos, tasa_retorno, ciclo_promedio_dias, vales_vencidos,
		            bajas_extravio, actualizado_en)
		SELECT id_mercado, mes, vales_emitidos, envases_prestados, envases_devueltos, tasa_retorno,
		       ciclo_promedio_dias, vales_vencidos, bajas_extravio, SYSDATETIME()
		  FROM dbo.v_indicadores_mensuales;
	COMMIT TRANSACTION;
END
GO

-- 12.4 Ley 29733 (RD-10): datos personales enmascarados para reportes
CREATE VIEW dbo.v_comerciante_reporte
AS
SELECT c.id_comerciante, p.id_mercado, p.codigo AS puesto,
       LEFT(c.doc_identidad, 2) + REPLICATE('*', LEN(c.doc_identidad) - 4)
         + RIGHT(c.doc_identidad, 2) AS doc_enmascarado,
       c.estado, c.indice_cumplimiento
  FROM dbo.comerciante c
  JOIN dbo.puesto p ON p.id_puesto = c.id_puesto
GO


-- ============================================================
-- 13. SEGURIDAD: INICIOS DE SESIÓN, ROLES, PRIVILEGIOS, ENMASCARAMIENTO
--     Y SEGURIDAD A NIVEL DE FILA (principio de mínimo privilegio)
-- Requiere autenticación mixta (SQL Server y Windows) para los inicios de sesión SQL.
-- ============================================================

-- 13.1 Inicios de sesión de los usuarios de servicio (nivel servidor).
--      Contraseñas de ejemplo: en producción se generan en el gestor de secretos y
--      se rotan cada 90 días.
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'app_ecovale')
	CREATE LOGIN app_ecovale    WITH PASSWORD = N'EcoVale_App#2026',    CHECK_POLICY = ON, DEFAULT_DATABASE = DB_EcoValeMercados;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'worker_ecovale')
	CREATE LOGIN worker_ecovale WITH PASSWORD = N'EcoVale_Worker#2026', CHECK_POLICY = ON, DEFAULT_DATABASE = DB_EcoValeMercados;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'bi_ecovale')
	CREATE LOGIN bi_ecovale     WITH PASSWORD = N'EcoVale_Bi#2026',     CHECK_POLICY = ON, DEFAULT_DATABASE = DB_EcoValeMercados;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'audit_ecovale')
	CREATE LOGIN audit_ecovale  WITH PASSWORD = N'EcoVale_Audit#2026',  CHECK_POLICY = ON, DEFAULT_DATABASE = DB_EcoValeMercados;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'backup_ecovale')
	CREATE LOGIN backup_ecovale WITH PASSWORD = N'EcoVale_Backup#2026', CHECK_POLICY = ON, DEFAULT_DATABASE = DB_EcoValeMercados;
GO

-- 13.2 Roles de base de datos y usuarios
CREATE USER ecovale_owner WITHOUT LOGIN          -- dueño lógico del DDL; solo migraciones
GO
ALTER ROLE db_ddladmin ADD MEMBER ecovale_owner
GO
CREATE ROLE rol_aplicacion                       -- API NestJS: DML controlado
GO
CREATE ROLE rol_proceso                          -- worker 00:05 y notificaciones
GO
CREATE ROLE rol_reporte                          -- Gerencia Ambiental: solo vistas
GO
CREATE ROLE rol_auditor                          -- lectura de la bitácora
GO

CREATE USER app_ecovale    FOR LOGIN app_ecovale
GO
CREATE USER worker_ecovale FOR LOGIN worker_ecovale
GO
CREATE USER bi_ecovale     FOR LOGIN bi_ecovale
GO
CREATE USER audit_ecovale  FOR LOGIN audit_ecovale
GO
CREATE USER backup_ecovale FOR LOGIN backup_ecovale
GO
ALTER ROLE rol_aplicacion    ADD MEMBER app_ecovale
GO
ALTER ROLE rol_proceso       ADD MEMBER worker_ecovale
GO
ALTER ROLE rol_reporte       ADD MEMBER bi_ecovale
GO
ALTER ROLE rol_auditor       ADD MEMBER audit_ecovale
GO
ALTER ROLE db_backupoperator ADD MEMBER backup_ecovale       -- solo copias de seguridad
GO

-- 13.3 Privilegios por objeto
-- Aplicación: lee y escribe, pero no elimina (RD-08) ni altera la bitácora
GRANT SELECT, INSERT, UPDATE ON SCHEMA::dbo TO rol_aplicacion
GO
GRANT EXECUTE ON SCHEMA::dbo TO rol_aplicacion
GO
DENY DELETE ON SCHEMA::dbo TO rol_aplicacion
GO
DENY UPDATE ON dbo.bitacora TO rol_aplicacion
GO

-- Proceso programado: solo lo necesario para vencer, notificar y refrescar
GRANT SELECT ON dbo.vale               TO rol_proceso
GO
GRANT SELECT ON dbo.detalle_vale       TO rol_proceso
GO
GRANT SELECT ON dbo.devolucion         TO rol_proceso
GO
GRANT SELECT ON dbo.detalle_devolucion TO rol_proceso
GO
GRANT SELECT ON dbo.comerciante        TO rol_proceso
GO
GRANT SELECT ON dbo.puesto             TO rol_proceso
GO
GRANT SELECT ON dbo.mercado            TO rol_proceso
GO
GRANT UPDATE (estado) ON dbo.vale TO rol_proceso
GO
GRANT UPDATE (estado, indice_cumplimiento) ON dbo.comerciante TO rol_proceso
GO
GRANT SELECT, INSERT, UPDATE ON dbo.notificacion TO rol_proceso
GO
GRANT INSERT ON dbo.bitacora TO rol_proceso
GO
GRANT EXECUTE ON dbo.sp_vencer_vales           TO rol_proceso
GO
GRANT EXECUTE ON dbo.sp_recalcular_comerciante TO rol_proceso
GO
GRANT EXECUTE ON dbo.sp_refrescar_indicadores  TO rol_proceso
GO

-- Reportes: vistas agregadas y datos personales enmascarados (Ley 29733)
GRANT SELECT ON dbo.v_inventario_mercado     TO rol_reporte
GO
GRANT SELECT ON dbo.mv_indicadores_mensuales TO rol_reporte
GO
GRANT SELECT ON dbo.v_comerciante_reporte    TO rol_reporte
GO

-- Auditoría: lectura de la bitácora sin acceso a otras tablas
GRANT SELECT ON dbo.bitacora TO rol_auditor
GO

-- 13.4 Enmascaramiento dinámico de datos personales (RD-10, Ley 29733).
--      Solo la aplicación ve el dato completo; cualquier otro usuario lo ve enmascarado.
ALTER TABLE comerciante ALTER COLUMN doc_identidad
	ADD MASKED WITH (FUNCTION = 'partial(2, "****", 2)')
GO
ALTER TABLE comerciante ALTER COLUMN telefono
	ADD MASKED WITH (FUNCTION = 'partial(0, "*******", 3)')
GO
GRANT UNMASK TO rol_aplicacion
GO

-- 13.5 Seguridad a nivel de fila (RNF-11): cada encargado ve solo su mercado.
--      La API fija en cada sesión: sp_set_session_context 'rol' y 'id_mercado'.
CREATE SCHEMA seguridad
GO

CREATE FUNCTION seguridad.fn_mercado_permitido
(
	@id_mercado bigint
)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
	SELECT 1 AS permitido
	 WHERE CAST(SESSION_CONTEXT(N'rol') AS varchar(15)) = 'ADMINISTRADOR'
	    OR @id_mercado = CAST(SESSION_CONTEXT(N'id_mercado') AS bigint)
	    OR IS_MEMBER('rol_proceso') = 1           -- el proceso programado recorre todos los mercados
	    OR IS_MEMBER('rol_reporte') = 1           -- reportes agregados de la municipalidad
	    OR IS_MEMBER('db_owner') = 1              -- administración y migraciones
GO

CREATE SECURITY POLICY seguridad.pol_mercado
	ADD FILTER PREDICATE seguridad.fn_mercado_permitido(id_mercado) ON dbo.vale,
	ADD BLOCK  PREDICATE seguridad.fn_mercado_permitido(id_mercado) ON dbo.vale AFTER INSERT,
	ADD BLOCK  PREDICATE seguridad.fn_mercado_permitido(id_mercado) ON dbo.vale AFTER UPDATE,
	ADD FILTER PREDICATE seguridad.fn_mercado_permitido(id_mercado) ON dbo.envase_unidad,
	ADD BLOCK  PREDICATE seguridad.fn_mercado_permitido(id_mercado) ON dbo.envase_unidad AFTER INSERT,
	ADD BLOCK  PREDICATE seguridad.fn_mercado_permitido(id_mercado) ON dbo.envase_unidad AFTER UPDATE,
	ADD FILTER PREDICATE seguridad.fn_mercado_permitido(id_mercado) ON dbo.inventario_mercado,
	ADD BLOCK  PREDICATE seguridad.fn_mercado_permitido(id_mercado) ON dbo.inventario_mercado AFTER INSERT,
	ADD BLOCK  PREDICATE seguridad.fn_mercado_permitido(id_mercado) ON dbo.inventario_mercado AFTER UPDATE,
	ADD FILTER PREDICATE seguridad.fn_mercado_permitido(id_mercado) ON dbo.puesto
	WITH (STATE = ON, SCHEMABINDING = ON)
GO

-- 13.6 Configuración recomendada del servidor (se realiza fuera del script):
--   * SQL Server Configuration Manager > Protocolos > Forzar cifrado = Sí (TLS 1.2).
--   * Firewall: puerto 1433 abierto solo para la subred privada de la API y del worker.
--   * Límite de conexiones por servicio: grupo de conexiones de la API (máximo 60).
--   * Cifrado del disco y de los archivos de datos con TDE (ediciones Standard 2019+ y Enterprise).


-- ============================================================
-- 14. RESPALDO Y TAREAS PROGRAMADAS (SQL Server Agent)
-- Copia completa diaria 01:00, diferencial 13:00 y del registro cada 5 minutos
-- (RPO de 5 minutos), cifradas con AES-256 y verificadas cada mes (RNF-17).
-- ============================================================

-- 14.1 Modelo de recuperación completo: permite copias del registro de
--      transacciones y la recuperación a un punto exacto en el tiempo
ALTER DATABASE DB_EcoValeMercados SET RECOVERY FULL
GO

-- 14.2 Certificado que cifra los respaldos (se crea en master)
USE master
GO
IF NOT EXISTS (SELECT 1 FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
	CREATE MASTER KEY ENCRYPTION BY PASSWORD = N'EcoVale_LlaveMaestra#2026';
IF NOT EXISTS (SELECT 1 FROM sys.certificates WHERE name = 'cert_respaldo_ecovale')
	CREATE CERTIFICATE cert_respaldo_ecovale
		WITH SUBJECT = 'Cifrado de respaldos de EcoVale Mercados (AES-256)';
GO
-- Guarde el certificado fuera del servidor: sin él no se puede restaurar un respaldo cifrado.
-- BACKUP CERTIFICATE cert_respaldo_ecovale TO FILE = 'D:\Seguro\cert_respaldo_ecovale.cer'
--     WITH PRIVATE KEY (FILE = 'D:\Seguro\cert_respaldo_ecovale.pvk',
--                       ENCRYPTION BY PASSWORD = '<contraseña del gestor de secretos>');
USE DB_EcoValeMercados
GO

-- 14.3 Tareas programadas. Cree antes la carpeta de respaldos indicada en @ruta.
--      SQL Server Express no incluye SQL Server Agent: en ese caso las tareas se omiten
--      y pueden ejecutarse con el Programador de tareas de Windows y sqlcmd.
DECLARE @ruta nvarchar(200) = N'C:\Respaldo\EcoVale\';

IF CAST(SERVERPROPERTY('Edition') AS nvarchar(128)) LIKE N'Express%'
	PRINT N'SQL Server Express no incluye SQL Server Agent: las tareas programadas se omiten.';
ELSE
BEGIN
	DECLARE @tareas TABLE (n int PRIMARY KEY, nombre sysname, comando nvarchar(max),
	                       freq_type int, freq_interval int, freq_subday_type int,
	                       freq_subday_interval int, freq_recurrence_factor int, hora int);
	INSERT INTO @tareas VALUES
	(1, N'EcoVale - Proceso 00:05 (vencimientos e indicadores)',
	    N'EXEC dbo.sp_vencer_vales; EXEC dbo.sp_refrescar_indicadores;',
	    4, 1, 1, 0, 0, 500),
	(2, N'EcoVale - Respaldo completo 01:00',
	    N'DECLARE @f nvarchar(260) = N''{R}ecovale_completo_'' + FORMAT(SYSDATETIME(), ''yyyyMMdd_HHmm'') + N''.bak'';
	      BACKUP DATABASE DB_EcoValeMercados TO DISK = @f
	      WITH COMPRESSION, CHECKSUM, NAME = N''EcoVale completo'',
	           ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = cert_respaldo_ecovale);',
	    4, 1, 1, 0, 0, 10000),
	(3, N'EcoVale - Respaldo diferencial 13:00',
	    N'DECLARE @f nvarchar(260) = N''{R}ecovale_diferencial_'' + FORMAT(SYSDATETIME(), ''yyyyMMdd_HHmm'') + N''.bak'';
	      BACKUP DATABASE DB_EcoValeMercados TO DISK = @f
	      WITH DIFFERENTIAL, COMPRESSION, CHECKSUM, NAME = N''EcoVale diferencial'',
	           ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = cert_respaldo_ecovale);',
	    4, 1, 1, 0, 0, 130000),
	(4, N'EcoVale - Respaldo del registro cada 5 minutos',
	    N'IF EXISTS (SELECT 1 FROM msdb.dbo.backupset WHERE database_name = N''DB_EcoValeMercados'' AND type = ''D'')
	      BEGIN
	        DECLARE @f nvarchar(260) = N''{R}ecovale_registro_'' + FORMAT(SYSDATETIME(), ''yyyyMMdd_HHmmss'') + N''.trn'';
	        BACKUP LOG DB_EcoValeMercados TO DISK = @f
	        WITH COMPRESSION, CHECKSUM,
	             ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = cert_respaldo_ecovale);
	      END',
	    4, 1, 4, 5, 0, 0),
	(5, N'EcoVale - Verificación y mantenimiento mensual',
	    N'DECLARE @f nvarchar(260) = (SELECT TOP (1) mf.physical_device_name
	                                   FROM msdb.dbo.backupset b
	                                   JOIN msdb.dbo.backupmediafamily mf ON mf.media_set_id = b.media_set_id
	                                  WHERE b.database_name = N''DB_EcoValeMercados'' AND b.type = ''D''
	                                  ORDER BY b.backup_finish_date DESC);
	      IF @f IS NOT NULL RESTORE VERIFYONLY FROM DISK = @f WITH CHECKSUM;
	      DBCC CHECKDB (DB_EcoValeMercados) WITH NO_INFOMSGS;
	      ALTER INDEX ALL ON dbo.vale REBUILD;
	      ALTER INDEX ALL ON dbo.detalle_vale REBUILD;
	      ALTER INDEX ALL ON dbo.devolucion REBUILD;
	      UPDATE STATISTICS dbo.vale WITH FULLSCAN;
	      UPDATE STATISTICS dbo.detalle_vale WITH FULLSCAN;
	      UPDATE STATISTICS dbo.devolucion WITH FULLSCAN;
	      UPDATE STATISTICS dbo.bitacora;',
	    16, 1, 1, 0, 1, 30000);

	DECLARE @i int = 1, @nombre sysname, @comando nvarchar(max), @ft int, @fi int, @fst int,
	        @fsi int, @frf int, @hora int;
	WHILE @i <= 5
	BEGIN
		SELECT @nombre = nombre, @comando = REPLACE(comando, N'{R}', @ruta), @ft = freq_type,
		       @fi = freq_interval, @fst = freq_subday_type, @fsi = freq_subday_interval,
		       @frf = freq_recurrence_factor, @hora = hora
		  FROM @tareas WHERE n = @i;

		IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @nombre)
			EXEC msdb.dbo.sp_delete_job @job_name = @nombre;

		EXEC msdb.dbo.sp_add_job @job_name = @nombre, @enabled = 1,
		     @description = N'EcoVale Mercados - Capítulo VII (respaldo y procesos programados)';
		EXEC msdb.dbo.sp_add_jobstep @job_name = @nombre, @step_name = N'Paso 1',
		     @subsystem = N'TSQL', @database_name = N'DB_EcoValeMercados', @command = @comando,
		     @retry_attempts = 2, @retry_interval = 5;
		EXEC msdb.dbo.sp_add_jobschedule @job_name = @nombre, @name = @nombre,
		     @freq_type = @ft, @freq_interval = @fi, @freq_subday_type = @fst,
		     @freq_subday_interval = @fsi, @freq_recurrence_factor = @frf,
		     @active_start_time = @hora;
		EXEC msdb.dbo.sp_add_jobserver @job_name = @nombre, @server_name = N'(local)';
		SET @i += 1;
	END
	PRINT N'Tareas de SQL Server Agent creadas: proceso 00:05, respaldos y mantenimiento mensual.';
END
GO

-- 14.4 Copia en otra región (RNF-17): además del disco local, el respaldo completo
--      puede enviarse a un almacenamiento en la nube con BACKUP ... TO URL, por ejemplo:
--   CREATE CREDENTIAL [https://<cuenta>.blob.core.windows.net/respaldos]
--       WITH IDENTITY = 'SHARED ACCESS SIGNATURE', SECRET = '<token SAS>';
--   BACKUP DATABASE DB_EcoValeMercados
--       TO URL = 'https://<cuenta>.blob.core.windows.net/respaldos/ecovale_completo.bak'
--       WITH COMPRESSION, CHECKSUM,
--            ENCRYPTION (ALGORITHM = AES_256, SERVER CERTIFICATE = cert_respaldo_ecovale);

-- 14.5 Restauración a un punto en el tiempo (prueba mensual en un servidor aislado):
--   RESTORE DATABASE DB_EcoValeMercados_Prueba
--       FROM DISK = N'C:\Respaldo\EcoVale\ecovale_completo_20261118_0100.bak'
--       WITH MOVE N'DB_EcoValeMercados' TO N'C:\Datos\EcoVale_Prueba.mdf',
--            MOVE N'DB_EcoValeMercados_log' TO N'C:\Datos\EcoVale_Prueba.ldf',
--            NORECOVERY, REPLACE;
--   RESTORE LOG DB_EcoValeMercados_Prueba
--       FROM DISK = N'C:\Respaldo\EcoVale\ecovale_registro_20261118_055500.trn'
--       WITH STOPAT = '2026-11-18T05:59:00', RECOVERY;


-- ============================================================
-- 15. DATOS SEMILLA Y PRUEBA DEL PROCESO PRINCIPAL
-- Escenario de la sección 1.3.1: Doña Rosa, puesto 14, 20 jabas.
-- Los errores esperados se capturan con TRY...CATCH y se muestran en Mensajes.
-- ============================================================
SET NOCOUNT ON
GO
EXEC sys.sp_set_session_context @key = N'clave_hmac', @value = N'clave-de-prueba-no-productiva'
GO

INSERT INTO municipalidad (nombre, ruc, distrito)
VALUES ('Municipalidad Provincial de Huancayo', '20146058871', 'Huancayo')
GO
INSERT INTO mercado (id_municipalidad, codigo, nombre, direccion, plazo_vale_dias)
VALUES (1, 'MMF', 'Mercado Mayorista de Frutas', 'Av. Ferrocarril s/n', 7),
       (1, 'MMH', 'Mercado Modelo de Huancayo',  'Jr. Ica 300',         7)
GO
INSERT INTO puesto (id_mercado, codigo, giro)
VALUES (1, 'P-014', 'Cítricos')
GO
INSERT INTO usuario (id_mercado, nombre_usuario, hash_contrasena, rol)
VALUES (NULL, 'admin.huancayo', '$2b$12$abcdefghijklmnopqrstuuJ0lHq2b7m2y1x9yq3h2yZbqzC1QeKa', 'ADMINISTRADOR'),
       (1,    'enc.mmf',        '$2b$12$abcdefghijklmnopqrstuuJ0lHq2b7m2y1x9yq3h2yZbqzC1QeKa', 'ENCARGADO'),
       (2,    'enc.mmh',        '$2b$12$abcdefghijklmnopqrstuuJ0lHq2b7m2y1x9yq3h2yZbqzC1QeKa', 'ENCARGADO')
GO
INSERT INTO comerciante (id_puesto, doc_identidad, nombres, telefono, consentimiento_datos)
VALUES (1, '41234567', 'Rosa Huamán Quispe', '+51964123456', 1)
GO
INSERT INTO tipo_envase (codigo, descripcion, material, capacidad, color, modo_identificacion, vida_util_ciclos)
VALUES ('JAB-PL-20', 'Jaba plástica de frutas', 'Polipropileno', '20 kg', 'Verde', 'POR_CANTIDAD', 60),
       ('CNT-HD-60', 'Contenedor con tapa',     'HDPE',          '60 L',  'Azul',  'POR_UNIDAD',  120)
GO
INSERT INTO inventario_mercado (id_mercado, id_tipo, cant_disponible)
VALUES (1, 1, 200)
GO
INSERT INTO envase_unidad (id_tipo, id_mercado, serial)
VALUES (2, 1, 'CNT-MMF-00001'), (2, 1, 'CNT-MMF-00002'), (2, 1, 'CNT-MMF-00003'),
       (2, 1, 'CNT-MMF-00004'), (2, 1, 'CNT-MMF-00005')
GO

PRINT '--- (1) Préstamo de 20 jabas y 1 contenedor a Doña Rosa'
EXEC dbo.sp_registrar_prestamo @id_comerciante = 1, @id_usuario = 2,
     @lineas = N'[{"id_tipo":1,"cantidad":20},{"id_unidad":1}]'
EXEC dbo.sp_confirmar_entrega @id_vale = 1, @id_usuario = 2
GO

PRINT '--- (2) Devolución parcial: 14 jabas (12 APTO + 2 NO APTO) y el contenedor'
EXEC dbo.sp_registrar_devolucion @id_vale = 1, @id_usuario = 2, @lineas = N'[
	{"id_detalle":1,"cantidad":12,"condicion":"APTO"},
	{"id_detalle":1,"cantidad":2,"condicion":"NO_APTO","tipo":"DANO",
	 "url_evidencia":"https://evidencias.ecovale.pe/mmf/val-1-foto1.jpg"},
	{"id_unidad":1,"condicion":"APTO"}]'
GO

PRINT '--- (3) Intento de devolver 10 jabas cuando el saldo es 6 (RD-05)'
BEGIN TRY
	EXEC dbo.sp_registrar_devolucion @id_vale = 1, @id_usuario = 2,
	     @lineas = N'[{"id_detalle":1,"cantidad":10,"condicion":"APTO"}]'
END TRY
BEGIN CATCH
	PRINT CONCAT('Rechazo esperado: ', ERROR_MESSAGE())
END CATCH
GO

PRINT '--- (4) Proceso de las 00:05, ocho días después: vencimiento (RF-29)'
DECLARE @corte datetime2(0) = DATEADD(DAY, 8, SYSDATETIME())
EXEC dbo.sp_vencer_vales @corte = @corte
SELECT folio, estado FROM dbo.vale
SELECT nombres, estado FROM dbo.comerciante
GO

PRINT '--- (5) Nuevo préstamo a un comerciante RESTRINGIDO (RD-04)'
BEGIN TRY
	EXEC dbo.sp_registrar_prestamo @id_comerciante = 1, @id_usuario = 2,
	     @lineas = N'[{"id_tipo":1,"cantidad":5}]'
END TRY
BEGIN CATCH
	PRINT CONCAT('Rechazo esperado: ', ERROR_MESSAGE())
END CATCH
GO

PRINT '--- (6) Regularización: devuelve las 6 jabas pendientes al día 9 (RN-19)'
DECLARE @dia9 datetime2(0) = DATEADD(DAY, 9, SYSDATETIME())
EXEC dbo.sp_registrar_devolucion @id_vale = 1, @id_usuario = 2,
     @lineas = N'[{"id_detalle":1,"cantidad":6,"condicion":"APTO"}]',
     @observacion = 'Regulariza saldo', @ocurrencia = @dia9
SELECT folio, estado, cerrado_fuera_plazo FROM dbo.vale
SELECT nombres, estado, indice_cumplimiento FROM dbo.comerciante
GO

PRINT '--- (7) Inventario resultante (RF-12)'
SELECT tipo, disponible, prestado, en_revision, dado_de_baja, total
  FROM dbo.v_inventario_mercado
 ORDER BY tipo
GO

PRINT '--- (8) Intentos de alterar la historia (RD-08)'
BEGIN TRY
	UPDATE dbo.bitacora SET accion = 'MODIFICAR' WHERE id_evento = 1
END TRY
BEGIN CATCH
	PRINT CONCAT('Rechazo esperado: ', ERROR_MESSAGE())
END CATCH
BEGIN TRY
	DELETE FROM dbo.vale WHERE id_vale = 1
END TRY
BEGIN CATCH
	PRINT CONCAT('Rechazo esperado: ', ERROR_MESSAGE())
END CATCH
GO

PRINT '--- (9) Bitácora generada automáticamente por los triggers (RF-36)'
SELECT accion, entidad, COUNT(*) AS eventos
  FROM dbo.bitacora
 GROUP BY entidad, accion
 ORDER BY entidad, accion
GO

PRINT '--- (10) Seguridad a nivel de fila: el encargado del Mercado Modelo no ve vales del MMF'
EXECUTE AS USER = 'app_ecovale'
EXEC sys.sp_set_session_context @key = N'rol', @value = N'ENCARGADO'
EXEC sys.sp_set_session_context @key = N'id_mercado', @value = 2
SELECT COUNT(*) AS vales_visibles_mmh FROM dbo.vale
EXEC sys.sp_set_session_context @key = N'id_mercado', @value = 1
SELECT COUNT(*) AS vales_visibles_mmf FROM dbo.vale
REVERT
EXEC sys.sp_set_session_context @key = N'rol', @value = NULL
EXEC sys.sp_set_session_context @key = N'id_mercado', @value = NULL
GO

-- Indicadores del tablero con los datos de prueba
EXEC dbo.sp_refrescar_indicadores
SELECT * FROM dbo.mv_indicadores_mensuales
GO


-- ============================================================
-- 16. DATOS SINTÉTICOS Y ESTADÍSTICAS DE USO DE LOS ÍNDICES
-- Simulan cinco años de operación (RNF-04). No se ejecutan automáticamente:
--     EXEC dbo.sp_cargar_datos_sinteticos;   -- 400 000 vales y 2,5 M de eventos
--     EXEC dbo.sp_medir_consultas;           -- Q1 a Q7 con STATISTICS IO y TIME
--     SELECT * FROM dbo.v_estadisticas_indices ORDER BY tabla, indice;
-- ============================================================
CREATE PROCEDURE dbo.sp_cargar_datos_sinteticos
	@vales            int = 400000,
	@eventos_bitacora int = 2500000
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;
	DECLARE @inicio datetime2(0) = '2021-11-18T05:00:00',
	        @segundos bigint = 157766400,                       -- cinco años
	        @hash varchar(100) = '$2b$12$abcdefghijklmnopqrstuuJ0lHq2b7m2y1x9yq3h2yZbqzC1QeKa',
	        @max_vale bigint = ISNULL((SELECT MAX(id_vale) FROM dbo.vale), 0),
	        @max_dev bigint, @muni bigint, @ncom int, @admin bigint;

	IF EXISTS (SELECT 1 FROM dbo.vale WHERE folio LIKE 'VAL-%-1[0-9][0-9][0-9][0-9][0-9]')
		THROW 50000, N'EV000: los datos sintéticos ya fueron cargados', 1;

	-- los triggers se desactivan solo durante la carga masiva
	DISABLE TRIGGER ALL ON dbo.usuario;
	DISABLE TRIGGER ALL ON dbo.comerciante;
	DISABLE TRIGGER ALL ON dbo.tipo_envase;
	DISABLE TRIGGER ALL ON dbo.vale;
	DISABLE TRIGGER ALL ON dbo.detalle_vale;
	DISABLE TRIGGER ALL ON dbo.devolucion;
	DISABLE TRIGGER ALL ON dbo.detalle_devolucion;

	BEGIN TRY
		-- tabla de números 1..N
		CREATE TABLE #n (n int NOT NULL PRIMARY KEY);
		INSERT INTO #n (n)
		SELECT TOP (CASE WHEN @eventos_bitacora > @vales THEN @eventos_bitacora ELSE @vales END)
		       ROW_NUMBER() OVER (ORDER BY (SELECT NULL))
		  FROM sys.all_columns a CROSS JOIN sys.all_columns b;

		-- organización: 5 mercados, 2 000 puestos, 3 000 comerciantes
		IF NOT EXISTS (SELECT 1 FROM dbo.municipalidad)
			INSERT INTO dbo.municipalidad (nombre, ruc, distrito)
			VALUES ('Municipalidad Provincial de Huancayo', '20146058871', 'Huancayo');
		SET @muni = (SELECT MIN(id_municipalidad) FROM dbo.municipalidad);

		INSERT INTO dbo.mercado (id_municipalidad, codigo, nombre, direccion)
		SELECT @muni, m.codigo, m.nombre, m.direccion
		  FROM (VALUES ('MMF', 'Mercado Mayorista de Frutas', 'Av. Ferrocarril s/n'),
		               ('MMH', 'Mercado Modelo de Huancayo',  'Jr. Ica 300'),
		               ('MET', 'Mercado de El Tambo',         'Av. Huancavelica 1200'),
		               ('MCH', 'Mercado de Chilca',           'Av. 9 de Diciembre 500'),
		               ('MCV', 'Mercado Centro Vecinal',      'Jr. Puno 210')) m (codigo, nombre, direccion)
		 WHERE NOT EXISTS (SELECT 1 FROM dbo.mercado x WHERE x.codigo = m.codigo);

		SELECT ROW_NUMBER() OVER (ORDER BY codigo) AS k, id_mercado, codigo
		  INTO #mer
		  FROM dbo.mercado
		 WHERE codigo IN ('MMF', 'MMH', 'MET', 'MCH', 'MCV');

		INSERT INTO dbo.usuario (id_mercado, nombre_usuario, hash_contrasena, rol)
		SELECT NULL, 'sint.admin', @hash, 'ADMINISTRADOR'
		 WHERE NOT EXISTS (SELECT 1 FROM dbo.usuario WHERE nombre_usuario = 'sint.admin')
		UNION ALL
		SELECT m.id_mercado, CONCAT('sint.enc.', LOWER(m.codigo)), @hash, 'ENCARGADO'
		  FROM #mer m
		 WHERE NOT EXISTS (SELECT 1 FROM dbo.usuario u WHERE u.nombre_usuario = CONCAT('sint.enc.', LOWER(m.codigo)));
		SET @admin = (SELECT id_usuario FROM dbo.usuario WHERE nombre_usuario = 'sint.admin');

		INSERT INTO dbo.puesto (id_mercado, codigo, giro)
		SELECT m.id_mercado, CONCAT('S-', RIGHT(CONCAT('000', p.n), 3)),
		       CHOOSE(1 + p.n % 5, 'Frutas', 'Verduras', 'Abarrotes', 'Carnes', 'Tubérculos')
		  FROM #mer m
		  JOIN #n p ON p.n <= 400
		 WHERE NOT EXISTS (SELECT 1 FROM dbo.puesto x
		                    WHERE x.id_mercado = m.id_mercado AND x.codigo = CONCAT('S-', RIGHT(CONCAT('000', p.n), 3)));

		SELECT ROW_NUMBER() OVER (ORDER BY id_mercado, codigo) AS k, id_puesto, id_mercado
		  INTO #pue
		  FROM dbo.puesto
		 WHERE codigo LIKE 'S-%' AND id_mercado IN (SELECT id_mercado FROM #mer);

		INSERT INTO dbo.comerciante (id_puesto, doc_identidad, nombres, telefono, consentimiento_datos)
		SELECT p.id_puesto, CAST(40000000 + c.n AS varchar(11)), CONCAT('Comerciante sintético ', c.n),
		       CONCAT('+5196', RIGHT(CONCAT('0000000', c.n), 7)), 1
		  FROM #n c
		  JOIN #pue p ON p.k = ((c.n - 1) % 2000) + 1
		 WHERE c.n <= 3000
		   AND NOT EXISTS (SELECT 1 FROM dbo.comerciante x WHERE x.doc_identidad = CAST(40000000 + c.n AS varchar(11)));

		SELECT ROW_NUMBER() OVER (ORDER BY co.id_comerciante) AS k, co.id_comerciante, p.id_mercado
		  INTO #com
		  FROM dbo.comerciante co
		  JOIN dbo.puesto p ON p.id_puesto = co.id_puesto
		 WHERE co.doc_identidad BETWEEN '40000001' AND '40003000';
		SET @ncom = (SELECT COUNT(*) FROM #com);

		-- envases: 4 tipos por cantidad y 2 por unidad; 5 000 unidades serializadas
		INSERT INTO dbo.tipo_envase (codigo, descripcion, material, capacidad, modo_identificacion, vida_util_ciclos)
		SELECT t.codigo, t.descripcion, t.material, t.capacidad, t.modo, t.vida
		  FROM (VALUES ('JAB-PL-20', 'Jaba plástica',      'PP',   '20 kg', 'POR_CANTIDAD', 60),
		               ('CAJ-PL-15', 'Caja plástica',      'PP',   '15 kg', 'POR_CANTIDAD', 60),
		               ('BAL-PL-20', 'Balde con asa',      'HDPE', '20 L',  'POR_CANTIDAD', 80),
		               ('CNT-PL-10', 'Contenedor bajo',    'PP',   '10 kg', 'POR_CANTIDAD', 60),
		               ('CNT-HD-60', 'Contenedor con tapa','HDPE', '60 L',  'POR_UNIDAD',  120),
		               ('JAB-RF-25', 'Jaba reforzada',     'HDPE', '25 kg', 'POR_UNIDAD',  150))
		       t (codigo, descripcion, material, capacidad, modo, vida)
		 WHERE NOT EXISTS (SELECT 1 FROM dbo.tipo_envase x WHERE x.codigo = t.codigo);

		SELECT ROW_NUMBER() OVER (ORDER BY id_tipo) - 1 AS k, id_tipo
		  INTO #tcant
		  FROM dbo.tipo_envase
		 WHERE codigo IN ('JAB-PL-20', 'CAJ-PL-15', 'BAL-PL-20', 'CNT-PL-10');
		SELECT ROW_NUMBER() OVER (ORDER BY id_tipo) - 1 AS k, id_tipo
		  INTO #tuni
		  FROM dbo.tipo_envase
		 WHERE codigo IN ('CNT-HD-60', 'JAB-RF-25');

		INSERT INTO dbo.inventario_mercado (id_mercado, id_tipo, cant_disponible, cant_prestada)
		SELECT m.id_mercado, t.id_tipo, 1500, 300
		  FROM #mer m CROSS JOIN #tcant t
		 WHERE NOT EXISTS (SELECT 1 FROM dbo.inventario_mercado x
		                    WHERE x.id_mercado = m.id_mercado AND x.id_tipo = t.id_tipo);

		INSERT INTO dbo.envase_unidad (id_tipo, id_mercado, serial, ciclos_realizados)
		SELECT tu.id_tipo, m.id_mercado, CONCAT('U-', RIGHT(CONCAT('000000', u.n), 6)), u.n % 90
		  FROM #n u
		  JOIN #tuni tu ON tu.k = u.n % 2
		  JOIN #mer m ON m.k = ((u.n - 1) / 1000) + 1
		 WHERE u.n <= 5000
		   AND NOT EXISTS (SELECT 1 FROM dbo.envase_unidad x WHERE x.serial = CONCAT('U-', RIGHT(CONCAT('000000', u.n), 6)));

		-- vales: emisión distribuida en cinco años y comerciantes intercalados
		SELECT b.n, e.emision, c.id_comerciante, c.id_mercado, b.r,
		       CASE WHEN e.emision > DATEADD(DAY, -7, SYSDATETIME())
		                 THEN CASE WHEN b.r < 0.6 THEN 'VIGENTE' ELSE 'PARCIAL' END
		            WHEN b.r < 0.004 THEN 'VENCIDO'
		            WHEN b.r < 0.014 THEN 'ANULADO'
		            WHEN b.r < 0.074 THEN 'OBSERVADO'
		            ELSE 'CERRADO' END AS estado,
		       1 + CAST(b.r * 1000 AS int) % 10 AS ciclo
		  INTO #base
		  FROM (SELECT n,
		               1 + CAST((CAST(n AS bigint) * 48271 % 2147483647) % @ncom AS int) AS kc,
		               (CAST(n AS bigint) * 69621 % 100000) / 100000.0 AS r
		          FROM #n WHERE n <= @vales) b
		  JOIN #com c ON c.k = b.kc
		 CROSS APPLY (SELECT DATEADD(SECOND, b.n % 10800,
		                     DATEADD(SECOND, CAST(@segundos * b.n / @vales AS int), @inicio)) AS emision) e;

		INSERT INTO dbo.vale (folio, id_mercado, id_comerciante, id_usuario_emisor, fecha_emision, fecha_limite,
		                      estado, firma_qr, motivo_anulacion, fecha_cierre, cerrado_fuera_plazo)
		SELECT CONCAT('VAL-', m.codigo, '-', YEAR(x.emision), '-',
		              RIGHT(CONCAT('000000', 100000 + ROW_NUMBER() OVER (PARTITION BY x.id_mercado, YEAR(x.emision)
		                                                                ORDER BY x.emision, x.n)), 6)),
		       x.id_mercado, x.id_comerciante, u.id_usuario, x.emision, DATEADD(DAY, 7, x.emision), x.estado,
		       LOWER(CONVERT(char(64), HASHBYTES('SHA2_256', CAST(x.n AS varchar(20))), 2)),
		       CASE WHEN x.estado = 'ANULADO' THEN 'Emitido por error de digitación' END,
		       CASE WHEN x.estado IN ('CERRADO', 'OBSERVADO') THEN DATEADD(DAY, x.ciclo, x.emision) END,
		       CASE WHEN x.estado IN ('CERRADO', 'OBSERVADO') AND x.ciclo > 7 THEN 1 ELSE 0 END
		  FROM #base x
		  JOIN #mer m ON m.id_mercado = x.id_mercado
		  JOIN dbo.usuario u ON u.nombre_usuario = CONCAT('sint.enc.', LOWER(m.codigo))
		 ORDER BY x.emision;

		-- líneas: 1 a 3 por vale, solo tipos POR_CANTIDAD
		INSERT INTO dbo.detalle_vale (id_vale, id_tipo, cantidad, cantidad_devuelta)
		SELECT v.id_vale, t.id_tipo, q.cant,
		       CASE v.estado WHEN 'CERRADO' THEN q.cant WHEN 'OBSERVADO' THEN q.cant
		                     WHEN 'PARCIAL' THEN q.cant / 2 WHEN 'VENCIDO' THEN q.cant / 3
		                     ELSE 0 END
		  FROM dbo.vale v
		 CROSS JOIN (VALUES (1), (2), (3)) k (k)
		 CROSS APPLY (SELECT 5 + CAST((v.id_vale * 7 + k.k * 13) % 26 AS int) AS cant) q
		  JOIN #tcant t ON t.k = (v.id_vale + k.k) % 4
		 WHERE v.id_vale > @max_vale AND k.k <= 1 + v.id_vale % 3;

		-- devoluciones: una o dos por vale con envases devueltos
		SET @max_dev = ISNULL((SELECT MAX(id_devolucion) FROM dbo.devolucion), 0);
		INSERT INTO dbo.devolucion (id_vale, id_usuario_receptor, fecha_hora)
		SELECT v.id_vale, v.id_usuario_emisor,
		       DATEADD(DAY, -(k.k - 1), ISNULL(v.fecha_cierre, DATEADD(DAY, 2, v.fecha_emision)))
		  FROM dbo.vale v
		 CROSS JOIN (VALUES (1), (2)) k (k)
		 WHERE v.id_vale > @max_vale
		   AND v.estado IN ('CERRADO', 'OBSERVADO', 'PARCIAL', 'VENCIDO')
		   AND k.k <= 1 + v.id_vale % 2;

		WITH dn AS (
			SELECT id_devolucion, id_vale,
			       ROW_NUMBER() OVER (PARTITION BY id_vale ORDER BY id_devolucion) AS pos,
			       COUNT(*) OVER (PARTITION BY id_vale) AS total
			  FROM dbo.devolucion
			 WHERE id_devolucion > @max_dev)
		INSERT INTO dbo.detalle_devolucion (id_devolucion, id_detalle_vale, cantidad, condicion)
		SELECT dn.id_devolucion, d.id_detalle,
		       CASE WHEN dn.total = 1 THEN d.cantidad_devuelta
		            WHEN dn.pos = 1   THEN d.cantidad_devuelta / 2
		            ELSE d.cantidad_devuelta - d.cantidad_devuelta / 2 END,
		       CASE WHEN v.estado = 'OBSERVADO' AND dn.pos = dn.total AND d.id_detalle % 2 = 0
		            THEN 'NO_APTO' ELSE 'APTO' END
		  FROM dbo.detalle_vale d
		  JOIN dbo.vale v ON v.id_vale = d.id_vale
		  JOIN dn ON dn.id_vale = d.id_vale
		 WHERE d.cantidad_devuelta > 0
		   AND (dn.total = 1 OR dn.pos = 2 OR d.cantidad_devuelta / 2 > 0);

		-- bitácora: eventos en orden cronológico (tabla de solo inserción)
		INSERT INTO dbo.bitacora (id_usuario, entidad, id_entidad, accion, valor_nuevo, fecha_hora)
		SELECT @admin,
		       CHOOSE(1 + n % 4, 'vale', 'devolucion', 'comerciante', 'incidencia'),
		       CAST(1 + (CAST(n AS bigint) * 7919) % 400000 AS varchar(40)),
		       CHOOSE(1 + n % 4, 'CREAR', 'MODIFICAR', 'MODIFICAR', 'CREAR'),
		       CONCAT(N'{"estado":"CERRADO","n":', n, N'}'),
		       DATEADD(SECOND, CAST(@segundos * n / @eventos_bitacora AS int), @inicio)
		  FROM #n
		 WHERE n <= @eventos_bitacora;

		-- coherencia: correlativos de folio y estado de los comerciantes
		MERGE dbo.serie_folio AS s
		USING (SELECT id_mercado, YEAR(fecha_emision) AS anio, MAX(CAST(RIGHT(folio, 6) AS int)) AS ultimo
		         FROM dbo.vale
		        GROUP BY id_mercado, YEAR(fecha_emision)) AS f
		   ON s.id_mercado = f.id_mercado AND s.anio = f.anio
		WHEN MATCHED AND s.ultimo_correlativo < f.ultimo THEN
			UPDATE SET ultimo_correlativo = f.ultimo
		WHEN NOT MATCHED THEN
			INSERT (id_mercado, anio, ultimo_correlativo) VALUES (f.id_mercado, f.anio, f.ultimo);

		UPDATE co
		   SET estado = CASE WHEN EXISTS (SELECT 1 FROM dbo.vale v
		                                   WHERE v.id_comerciante = co.id_comerciante AND v.estado = 'VENCIDO')
		                     THEN 'RESTRINGIDO' ELSE 'HABILITADO' END
		  FROM dbo.comerciante co
		  JOIN #com c ON c.id_comerciante = co.id_comerciante;
	END TRY
	BEGIN CATCH
		ENABLE TRIGGER ALL ON dbo.usuario;
		ENABLE TRIGGER ALL ON dbo.comerciante;
		ENABLE TRIGGER ALL ON dbo.tipo_envase;
		ENABLE TRIGGER ALL ON dbo.vale;
		ENABLE TRIGGER ALL ON dbo.detalle_vale;
		ENABLE TRIGGER ALL ON dbo.devolucion;
		ENABLE TRIGGER ALL ON dbo.detalle_devolucion;
		THROW;
	END CATCH;

	ENABLE TRIGGER ALL ON dbo.usuario;
	ENABLE TRIGGER ALL ON dbo.comerciante;
	ENABLE TRIGGER ALL ON dbo.tipo_envase;
	ENABLE TRIGGER ALL ON dbo.vale;
	ENABLE TRIGGER ALL ON dbo.detalle_vale;
	ENABLE TRIGGER ALL ON dbo.devolucion;
	ENABLE TRIGGER ALL ON dbo.detalle_devolucion;

	UPDATE STATISTICS dbo.vale WITH FULLSCAN;
	UPDATE STATISTICS dbo.detalle_vale WITH FULLSCAN;
	UPDATE STATISTICS dbo.devolucion WITH FULLSCAN;
	UPDATE STATISTICS dbo.detalle_devolucion WITH FULLSCAN;
	UPDATE STATISTICS dbo.bitacora;
	EXEC dbo.sp_refrescar_indicadores;

	SELECT (SELECT COUNT(*) FROM dbo.vale)               AS vales,
	       (SELECT COUNT(*) FROM dbo.detalle_vale)       AS lineas_de_vale,
	       (SELECT COUNT(*) FROM dbo.devolucion)         AS devoluciones,
	       (SELECT COUNT(*) FROM dbo.detalle_devolucion) AS lineas_de_devolucion,
	       (SELECT COUNT(*) FROM dbo.bitacora)           AS eventos_de_bitacora;
END
GO

-- Consultas críticas Q1 a Q7 del capítulo VII. Los tiempos y lecturas lógicas
-- aparecen en la pestaña Mensajes de SQL Server Management Studio.
CREATE PROCEDURE dbo.sp_medir_consultas
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @folio varchar(30), @id_com bigint, @id_mer bigint, @id_vale bigint,
	        @desde datetime2(0), @hasta datetime2(0);

	SELECT TOP (1) @folio = folio, @id_com = id_comerciante, @id_mer = id_mercado, @id_vale = id_vale
	  FROM dbo.vale
	 ORDER BY id_vale DESC;
	SELECT @hasta = MAX(fecha_emision) FROM dbo.vale WHERE id_mercado = @id_mer;
	SET @desde = DATEFROMPARTS(YEAR(@hasta), MONTH(@hasta), 1);

	SET STATISTICS IO ON;
	SET STATISTICS TIME ON;

	PRINT 'Q1. Vale y líneas por folio (RF-21)';
	SELECT v.folio, v.estado, d.id_tipo, d.cantidad, d.cantidad_devuelta
	  FROM dbo.vale v JOIN dbo.detalle_vale d ON d.id_vale = v.id_vale
	 WHERE v.folio = @folio;

	PRINT 'Q2. ¿Tiene vales VENCIDOS? (RF-15)';
	SELECT CASE WHEN EXISTS (SELECT 1 FROM dbo.vale
	                          WHERE id_comerciante = @id_com AND estado = 'VENCIDO')
	            THEN 1 ELSE 0 END AS tiene_vencidos;

	PRINT 'Q3. Pendientes de un comerciante (RF-31)';
	SELECT folio, tipo, pendiente, dias_atraso
	  FROM dbo.v_vales_pendientes
	 WHERE id_comerciante = @id_com;

	PRINT 'Q4. Vales por vencer a las 00:05 (RF-29)';
	SELECT id_vale, fecha_limite
	  FROM dbo.vale
	 WHERE estado IN ('VIGENTE', 'PARCIAL') AND fecha_limite < DATEADD(DAY, 1, SYSDATETIME());

	PRINT 'Q5. Tablero mensual de un mercado (RF-33)';
	SELECT COUNT(*) AS emitidos,
	       SUM(CASE WHEN estado IN ('CERRADO', 'OBSERVADO') THEN 1 ELSE 0 END) AS cerrados,
	       SUM(CASE WHEN estado = 'VENCIDO' THEN 1 ELSE 0 END) AS vencidos
	  FROM dbo.vale
	 WHERE id_mercado = @id_mer AND fecha_emision >= @desde AND fecha_emision < DATEADD(MONTH, 1, @desde);

	PRINT 'Q6. Bitácora de un vale (HU-21)';
	SELECT id_evento, accion, fecha_hora
	  FROM dbo.bitacora
	 WHERE entidad = 'vale' AND id_entidad = CAST(@id_vale AS varchar(40))
	 ORDER BY fecha_hora DESC;

	PRINT 'Q7. Bitácora de una semana (HU-21)';
	SELECT COUNT(*) AS eventos
	  FROM dbo.bitacora
	 WHERE fecha_hora >= DATEADD(DAY, -7, @hasta) AND fecha_hora < @hasta;

	SET STATISTICS TIME OFF;
	SET STATISTICS IO OFF;
END
GO

-- Uso, tamaño y tipo de cada índice (estadísticas de uso)
CREATE VIEW dbo.v_estadisticas_indices
AS
SELECT OBJECT_NAME(i.object_id)  AS tabla,
       i.name                    AS indice,
       i.type_desc               AS tipo,
       i.is_unique               AS unico,
       i.has_filter              AS filtrado,
       ps.row_count              AS filas,
       ps.used_page_count * 8    AS tamano_kb,
       us.user_seeks             AS busquedas,
       us.user_scans             AS recorridos,
       us.user_lookups           AS busquedas_por_clave,
       us.user_updates           AS actualizaciones,
       us.last_user_seek         AS ultima_busqueda
  FROM sys.indexes i
  JOIN sys.dm_db_partition_stats ps
    ON ps.object_id = i.object_id AND ps.index_id = i.index_id
  LEFT JOIN sys.dm_db_index_usage_stats us
    ON us.object_id = i.object_id AND us.index_id = i.index_id AND us.database_id = DB_ID()
 WHERE OBJECTPROPERTY(i.object_id, 'IsUserTable') = 1
   AND i.index_id > 0
GO

PRINT N'Base de datos DB_EcoValeMercados creada y probada correctamente.'
GO


--EJEMPLO DE SOLICITUD
USE DB_EcoValeMercados;
GO
-- Obligatorio: cada ventana nueva es otra sesión y no tiene la clave HMAC
EXEC sys.sp_set_session_context @key = N'clave_hmac', @value = N'clave-de-prueba-no-productiva';

-- Solicitud: Doña Rosa (comerciante 1), atendida por enc.mmf (usuario 2)
EXEC dbo.sp_registrar_prestamo
     @id_comerciante = 1,
     @id_usuario     = 2,
     @lineas = N'[{"id_tipo":1,"cantidad":10},{"id_unidad":2}]';

--EJEMPLO DE SOLICITUD INCORRECTA
USE DB_EcoValeMercados;
GO
-- Obligatorio: cada ventana nueva es otra sesión y no tiene la clave HMAC
EXEC sys.sp_set_session_context @key = N'clave_hmac', @value = N'clave-de-prueba-no-productiva';

-- Solicitud: Doña Rosa (comerciante 1), atendida por enc.mmf (usuario 2)
EXEC dbo.sp_registrar_prestamo
     @id_comerciante = 1,
     @id_usuario     = 2,
     @lineas = N'[{"id_tipo":1,"cantidad":10},{"id_unidad":2}]';

SELECT folio, estado, fecha_limite FROM dbo.vale;
SELECT tipo, disponible, prestado FROM dbo.v_inventario_mercado;