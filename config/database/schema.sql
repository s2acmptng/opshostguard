-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Servidor: 127.0.0.1
-- Tiempo de generación: 28-10-2024 a las 05:40:00
-- Versión del servidor: 8.0.33
-- Versión de PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de datos: `opshostguard`
--

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `hardware_inventory`
--

CREATE TABLE `hardware_inventory` (
  `id` int NOT NULL,
  `host_name` varchar(255) NOT NULL,
  `cpu_model` varchar(255) DEFAULT NULL,
  `cpu_cores` int DEFAULT NULL,
  `ram_capacity_gb` int DEFAULT NULL,
  `network_adapter` varchar(255) DEFAULT NULL,
  `mac_adapter` varchar(60) DEFAULT NULL,
  `motherboard` varchar(255) DEFAULT NULL,
  `bios_version` varchar(50) DEFAULT NULL,
  `bios_release_date` datetime DEFAULT NULL,
  `os_caption` varchar(255) DEFAULT NULL,
  `os_build_number` varchar(50) DEFAULT NULL,
  `gpu_model` varchar(255) DEFAULT NULL,
  `gpu_driver_version` varchar(50) DEFAULT NULL,
  `inventory_datestamp` date NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `host_metrics`
--

CREATE TABLE `host_metrics` (
  `id` int NOT NULL,
  `host_name` varchar(255) NOT NULL,
  `cpu_usage` decimal(5,2) DEFAULT NULL,
  `ram_usage` decimal(5,2) DEFAULT NULL,
  `disk1_usage` decimal(5,2) DEFAULT NULL,
  `disk2_usage` decimal(5,2) DEFAULT NULL,
  `disk3_usage` decimal(5,2) DEFAULT NULL,
  `timestamp` datetime NOT NULL,
  `update_names` text,
  `update_status` varchar(50) DEFAULT NULL,
  `session_active` tinyint(1) DEFAULT NULL,
  `session_name` varchar(255) DEFAULT NULL,
  `shutdown_status` varchar(50) DEFAULT NULL,
  `power_on_failure_time` datetime DEFAULT NULL,
  `shutdown_failure_time` datetime DEFAULT NULL,
  `boot_time` time DEFAULT NULL,
  `script_version` varchar(10) DEFAULT NULL,
  `admin_comments` text,
  `inventory_datestamp` date DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Estructura de tabla para la tabla `host_summary`
--

CREATE TABLE `host_summary` (
  `id` int NOT NULL,
  `total_hosts` int DEFAULT NULL,
  `failed_hosts_count` int DEFAULT NULL,
  `failed_percentage` decimal(5,2) DEFAULT NULL,
  `high_load_percentage` decimal(5,2) DEFAULT NULL,
  `critical_Error_percentage` decimal(5,2) DEFAULT NULL,
  `active_session_percentage` decimal(5,2) DEFAULT NULL,
  `total_updates_installed` int DEFAULT NULL,
  `total_critical_logs` int DEFAULT NULL,
  `total_Error_logs` int DEFAULT NULL,
  `total_active_sessions` int DEFAULT NULL,
  `total_hosts_shutdown_failed` int DEFAULT NULL,
  `overall_status` varchar(50) DEFAULT NULL,
  `execution_start_time` datetime NOT NULL,
  `execution_end_time` datetime NOT NULL,
  `time_check` varchar(10) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Volcado de datos para la tabla `host_summary`
--

INSERT INTO `host_summary` (`id`, `total_hosts`, `failed_hosts_count`, `failed_percentage`, `high_load_percentage`, `critical_Error_percentage`, `active_session_percentage`, `total_updates_installed`, `total_critical_logs`, `total_Error_logs`, `total_active_sessions`, `total_hosts_shutdown_failed`, `overall_status`, `execution_start_time`, `execution_end_time`, `time_check`) VALUES
(2, 4, 2, 50.00, 0.00, 0.00, 100.00, 0, 0, 0, 4, 0, 'Partial Failures', '2024-10-28 02:03:35', '2024-10-28 02:05:56', '00:02:20');

--
-- Índices para tablas volcadas
--

--
-- Indices de la tabla `hardware_inventory`
--
ALTER TABLE `hardware_inventory`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_host_time` (`host_name`,`inventory_datestamp`);

--
-- Indices de la tabla `host_metrics`
--
ALTER TABLE `host_metrics`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_host_metrics_hardware_inventory` (`host_name`,`inventory_datestamp`);

--
-- Indices de la tabla `host_summary`
--
ALTER TABLE `host_summary`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT de las tablas volcadas
--

--
-- AUTO_INCREMENT de la tabla `hardware_inventory`
--
ALTER TABLE `hardware_inventory`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT de la tabla `host_metrics`
--
ALTER TABLE `host_metrics`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT de la tabla `host_summary`
--
ALTER TABLE `host_summary`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- Restricciones para tablas volcadas
--

--
-- Filtros para la tabla `host_metrics`
--
ALTER TABLE `host_metrics`
  ADD CONSTRAINT `fk_host_metrics_hardware_inventory` FOREIGN KEY (`host_name`,`inventory_datestamp`) REFERENCES `hardware_inventory` (`host_name`, `inventory_datestamp`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
