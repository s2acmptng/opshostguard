-- OpsHostGuard Database Schema Definition
--
-- Author: Alberto Ledo
-- Organization: Faculty of Documentation and Communication Sciences, University of Extremadura
-- Date: November 16, 2024
-- Version: 2.0.0
--
-- DESCRIPTION:
-- This SQL script defines the schema for the OpsHostGuard application, including the tables and relationships 
-- required for storing host metrics, availability tracking, hardware inventory, scan history, and summary data.
-- The schema ensures consistency and supports both real-time operations and historical data storage.
--
-- TABLES:
-- - `host_metrics`: Stores performance and operational metrics for individual hosts.
-- - `hosts_availability`: Tracks online/offline status and downtime of hosts.
-- - `hardware_inventory`: Maintains detailed hardware specifications for each host.
-- - `host_summary`: Provides aggregated metrics and system-wide summary data.
-- - `ops_scan_history`: Logs metadata about scans performed on the host system.
--
-- NOTES:
-- - The schema is designed for use with MySQL and includes constraints and data types optimized for 
--   efficient storage and queries.
-- - Ensure that any modifications to this schema are reflected in the application and accompanying documentation.
--
-- LICENSE:
-- Provided "as-is" for internal University of Extremadura use. Modifications are not covered.
--
-- LINKS:
-- Project: https://github.com/n7rc/OpsHostGuard
-- Documentation: https://github.com/n7rc/OpsHostGuard/wiki


-- Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS opshostguard;

-- Use the created database
USE opshostguard;

-- Table: host_metrics
-- Stores detailed performance metrics for each host, such as CPU and RAM usage, disk usage, and operational statuses.
CREATE TABLE IF NOT EXISTS host_metrics (
    id INT AUTO_INCREMENT PRIMARY KEY,            -- Unique identifier for each entry
    host_name VARCHAR(255) NOT NULL,              -- Host name
    cpu_usage DECIMAL(5, 2) NULL,                 -- CPU usage in percentage
    ram_usage DECIMAL(5, 2) NULL,                 -- RAM usage in percentage
    disk1_usage DECIMAL(5, 2) NULL,               -- Usage of the primary disk in percentage
    disk2_usage DECIMAL(5, 2) NULL DEFAULT NULL,  -- Usage of the secondary disk (if available)
    disk3_usage DECIMAL(5, 2) NULL DEFAULT NULL,  -- Usage of the tertiary disk (if available)
    timestamp DATETIME NOT NULL,                  -- Timestamp of the performance check
    update_names TEXT NULL,                       -- Names of updates applied
    update_status VARCHAR(50) NULL,               -- Status of updates (e.g., Success, Failed, No Updates Found)
    session_active BOOLEAN,                       -- Indicates if an active session was present during the check
    session_name VARCHAR(255) NULL,               -- Name of the session user
    shutdown_status VARCHAR(50) NULL,             -- Shutdown status (e.g., Success, Failed)
    power_on_failure_time DATETIME DEFAULT NULL,  -- Time of the last power-on failure
    shutdown_failure_time DATETIME DEFAULT NULL,  -- Time of the last shutdown failure
    boot_time TIME NULL,                          -- Boot duration time
    ip_address VARCHAR(45) DEFAULT NULL,          -- IP address (supports IPv4/IPv6)
    mac_address VARCHAR(17) DEFAULT NULL,         -- MAC address
    last_update_time TIMESTAMP DEFAULT NULL,      -- Time of the last update check
    last_session_user VARCHAR(255) DEFAULT NULL,  -- User of the last active session
    uptime INT DEFAULT NULL,                      -- System uptime in minutes
    pending_reboot BOOLEAN DEFAULT FALSE,         -- Indicates if the system requires a reboot
    disk_health_status VARCHAR(50) DEFAULT 'Healthy', -- Health status of the disk(s) (e.g., Healthy, Degraded)
    script_version VARCHAR(10),                   -- Version of the script used for the check
    admin_comments TEXT NULL,                     -- Comments or notes by the administrator
    inventory_datestamp DATE                      -- References the associated hardware inventory record
);

-- Table: hosts_availability
-- Tracks the availability status (online/offline) of each host over time.
CREATE TABLE IF NOT EXISTS hosts_availability (
    host_name VARCHAR(255) NOT NULL,             -- Host name
    availability_status ENUM('Online', 'Offline') NOT NULL, -- Current availability status
    last_seen TIMESTAMP DEFAULT NULL,            -- Timestamp of the last known status
    downtime_duration INT DEFAULT 0,             -- Total downtime in minutes
    PRIMARY KEY (host_name)                      -- Ensures each host has a unique availability record
);

-- Table: hardware_inventory
-- Stores detailed hardware information for each host, including CPU, RAM, and motherboard details.
CREATE TABLE IF NOT EXISTS hardware_inventory (
    id INT AUTO_INCREMENT PRIMARY KEY,          -- Unique identifier for each entry
    host_name VARCHAR(255) NOT NULL,            -- Host name
    cpu_model VARCHAR(255),                     -- CPU model name
    cpu_cores INT,                              -- Number of CPU cores
    ram_capacity_gb INT,                        -- RAM capacity in gigabytes
    network_adapter VARCHAR(255),               -- Network adapter details
    mac_adapter VARCHAR(60),                    -- MAC address of the primary network adapter
    motherboard VARCHAR(255),                   -- Motherboard details
    bios_version VARCHAR(50),                   -- BIOS version
    bios_release_date DATETIME,                 -- BIOS release date
    os_caption VARCHAR(255),                    -- Operating system name
    os_build_number VARCHAR(50),                -- Operating system build number
    gpu_model VARCHAR(255),                     -- GPU (graphics card) model
    gpu_driver_version VARCHAR(50),             -- GPU driver version
    inventory_datestamp DATE NOT NULL,          -- Timestamp of the hardware inventory record
    UNIQUE (host_name, inventory_datestamp)     -- Ensures unique inventory entries per host and timestamp
);

-- Table: host_summary
-- Provides a high-level summary of a system check, such as total hosts scanned and failure rates.
CREATE TABLE IF NOT EXISTS host_summary (
    id INT AUTO_INCREMENT PRIMARY KEY,          -- Unique identifier for each summary
    total_hosts INT,                            -- Total number of hosts checked
    failed_hosts_count INT,                     -- Number of hosts that failed checks
    failed_percentage DECIMAL(5, 2),            -- Percentage of failed hosts
    high_load_percentage DECIMAL(5, 2),         -- Percentage of hosts with high CPU/RAM load
    critical_Error_percentage DECIMAL(5, 2),    -- Percentage of hosts with critical errors
    active_session_percentage DECIMAL(5, 2),    -- Percentage of hosts with active sessions
    total_updates_installed INT,                -- Total updates installed during the check
    total_critical_logs INT,                    -- Total critical logs found
    total_Error_logs INT,                       -- Total error logs found
    total_active_sessions INT,                  -- Total active sessions detected
    total_hosts_shutdown_failed INT,            -- Total number of hosts that failed to shut down
    overall_status VARCHAR(50),                 -- Overall status (e.g., Success, Partial Failures)
    execution_start_time DATETIME NOT NULL,     -- Start time of the check
    execution_end_time DATETIME NOT NULL,       -- End time of the check
    time_check VARCHAR(10) NOT NULL             -- Duration of the check
);

-- Table: ops_scan_history
-- Logs metadata about each scan operation, such as its type and status.
CREATE TABLE IF NOT EXISTS ops_scan_history (
    scan_id INT AUTO_INCREMENT PRIMARY KEY,     -- Unique identifier for each scan
    scan_type ENUM('Scheduled', 'Manual') NOT NULL, -- Type of scan
    start_time TIMESTAMP NOT NULL,              -- Start time of the scan
    end_time TIMESTAMP DEFAULT NULL,            -- End time of the scan
    status ENUM('Completed', 'Failed') NOT NULL -- Result of the scan
);

-- Add foreign key constraint to link host_metrics with hardware_inventory
ALTER TABLE host_metrics
ADD CONSTRAINT fk_host_metrics_hardware_inventory
FOREIGN KEY (host_name, inventory_datestamp) REFERENCES hardware_inventory(host_name, inventory_datestamp)
ON DELETE CASCADE;
