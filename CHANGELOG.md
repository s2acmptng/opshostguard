# OpsHostGuard Change Log

## [2.6.0] - 2024-11-04
- Added log message capture functionality during application initialization.

## [2.5.0] - 2024-10-20
- Introduced DNS resolution support.
- Added silent mode to reduce console output in non-critical scenarios.

## [2.3.0] - 2024-09-05
- Implemented secure credential storage for dashboard and database access.
- Added user access control functionality to the dashboard.
...

REVISAR
2.2.4 Conversion de $g y $h a $GroupName y $HostName
2.2.3 Conversión de módulo UpdateHosts en módulo autónomo.
3.0.1 Modificación de LogManager para centralizar la gestión de Logs en unúnico módulo
3.0.0 Control de persistencia y limpieza del entorno global entre sesiones de powershell.
2.9.0 Incorporados adicción de plugins
3.2.3 Simplificaciónd e la gestion de log y us funciones d elñog temporales.
3.4.0 Added support for multi-interface hosts with RPC validation on multiple IPs; configurable IP prefix setting.
3.4.1 Added StopHosts como módulo.
3.4.2 Added ActiveSessions como módulo.
3.4.2-rc Wrapper export as function aliases in standalone mode..
3.5.0-rc Rewrite of the configuration module and core modules to optimize performance and improve scalability. Structural modifications in critical modules to support new functionalities.
3.5.2- Refactorización de la inicialización de módulos core standalone. Nueva función New-CoreStandalone.
4.0.0-alpha Desacoplamiento de OpsVar. Nuevo módulo de seguridad para la gestión centralizada y funcional de credenciales. Módulo opcional CReateDatabase para la creación automatizada de la base de datos de la aplicación. Modificación de la base de datos (Incorporación de tablas y columnas en la tabla principal host_metrics)
4.0.2-alpha Establecimiento de relación 1:1 entra las tablas SQL y las plantillas de datos básicas para insercción SQL y consumo PHP. 
4.1.0-alpha Delegación de responsabilidades particulares de configiracióne n Initialize-GlobalConfig, miembro de OpsInit. Mejora de propagación de parámetros de usuario entre mnódulos y funciones. Adición de valores por defecto enlos parámetros esperados en modo standalone par alos módulos core.
5.0.0 - Reconversión de la varibale Global $Global:Config. Incorporación de evaluación y métricas para un único host y una lista arbitraria de hosts no pertenecientes a ningún grupo. Refactorización de código. Mejora de mensajes de salida en consola y logs. Mejora dee modo Debug. CReación de nuevas funciones New-TemporaryGroup y Export-UpdateResults


1.0.0 - Initial version by Alberto Ledo.
    1.1.0 - Added email reporting for power-on, shutdown, and session detection.
    1.2.0 - Introduced the `-UpdateHosts` parameter for optional host update functionality.
    1.3.0 - Integrated the `-g` parameter for specifying host groups, with "all" as default.
    1.4.0 - Added the use of stored credentials for remote operations and enhanced logging features.
    1.5.0 - Included host load monitoring (CPU, RAM, Disk) and resource usage alerts in email reports.
    1.6.0 - Integrated the PSWindowsUpdate module for host updates based on the `-UpdateHosts` parameter.
    1.7.0 - Added the retrieval of active session details on hosts.
    1.8.0 - Added critical and Error log capture from System, Setup, and Application logs.
    1.9.0 - Introduced HTML report generation with print preview and PDF export functionality.
    2.0.0 - Added CSV and log export for host and summary data, and generated SQL queries for database .
    2.1.0 - Added hardware inventory functionality, including CPU, Network Adapter, Motherboard, BIOS, OS, and GPU collection.
    2.2.0 - Added user logon functionality for secured access control to the dashboard.
    2.2.1 - Modified Stop-MGHosts to return more Information.
    2.3.0 - Integrated secure credential storage for database and dashboard access using `Create-Credentials.ps1`.
    2.3.1 - Introduced historical tracking for hardware inventory in host metrics with `inventory_datestamp`.
    2.3.2 - Added the dynamic generation or update of a PHP configuration file. Incorporation of powershell modules:
            OpsHostGuardGlobalConfig and OpsHostGuardConfigPhp.
    2.3.3 - Bug fixing.
    2.3.4 - Application Modularization.
    2.4.0 - Modification of application settings: user_config.json file.
    2.5.0 - Incorporation of DNS resolution.
    2.5.1 - Incorporation of silent mode.
    2.5.2 - Added logging file system.
    2.5.3 - Added UpdateHost moduleadministrador.
    2.5.4 - Bug fixing.
    2.6.0 - Added log message capture functionality during application initialization.
