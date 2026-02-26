// main.js [OpsHostGuard]

/**
 * @SYNOPSIS
 * Automates the generation of daily reports for classroom or host groups, including table data extraction, print preview generation, 
 * PDF export, and the application of host and event filters. This script integrates with the HTML interface, enabling administrators 
 * to monitor and manage the status of classrooms or host groups.
 * 
 * @DESCRIPTION
 * This JavaScript file supports the following key functionalities in the "OpsHostGuard" project:
 *
 * 1. Generates a print preview of daily reports for classrooms or host groups, extracting data from HTML tables based on host power and shutdown status.
 * 2. Supports exporting HTML content as PDF, excluding specified sections (e.g., buttons, headers).
 * 3. Applies dynamic filters to report tables, allowing filtering by specific criteria, such as host name and event type.
 * 4. Provides a reset option for filters, restoring tables to the default view and displaying all rows.
 * 5. Automatically generates file names for PDF exports, ensuring data consistency across reports.
 * 6. Allows hardware inventory data export in PDF format, supporting a wider layout in A3 landscape orientation for detailed reports.
 * 7. Generates a print-friendly HTML view for classroom or host group reports, supporting direct print actions from the browser.
 *
 * @EXAMPLE
 * openPrintPreview();
 * // Generates a print preview of the daily report with extracted table data, suitable for manual review or printing.
 *
 * @EXAMPLE
 * generatePDF();
 * // Exports the classroom hosts report as a PDF file, ensuring that only relevant data is included and appropriately formatted.
 *
 * @EXAMPLE
 * generateInventoryPDF();
 * // Exports the hardware inventory report of classroom hosts into a PDF file in landscape orientation for improved readability.
 *
 * @PARAMETER hostFilter
 * Specifies the host to filter in the table. If "all" is selected, all hosts are displayed.
 *
 * @PARAMETER eventType
 * Specifies the event type to filter in the table. If "all" is selected, all event types are displayed.
 *
 * @PARAMETER content
 * Refers to the container element with the content to be exported (e.g., reports or tables). The script clones the content 
 * to avoid modifying the original DOM.
 *
 * @NOTES
 * - Designed for use with the HTML interface for the "OpsHostGuard" project.
 * - Integrates with the `html2pdf.js` library for PDF generation.
 * - Filters applied to the report affect the displayed content, and only visible rows are included in the export or print views.
 * - The script dynamically generates file names based on the current date for efficient report tracking and organization.
 *
 * @ORGANIZATION
 * Developed for: Faculty of Documentation and Communication Sciences at the University of Extremadura.
 *
 * @AUTHOR
 * Alberto Ledo [Faculty of Documentation and Communication Sciences] with assistance from OpenAI.
 * IT Department, University of Extremadura - IT Services for Facilities
 * Contact: albertoledo@unex.es
 * 
 * @Copyright
 * © 2024 Alberto Ledo
 *
 * @VERSION
 * 1.3.0
 *
 * @HISTORY
 * 1.0 - Initial version by Alberto Ledo.
 * 1.1 - Added PDF export functionality with `html2pdf.js` integration.
 * 1.2 - Introduced filtering capabilities for classroom or host group reports.
 * 1.3 - Added print preview generation, hardware inventory PDF export, and enhanced reporting features.
 *
 * @USAGE
 * This script is intended solely for internal use at University of Extremadura. It is designed to operate within the 
 * university's IT infrastructure and may not perform as expected in other environments.
 *
 * @DATE
 * October 28, 2024
 *
 * @DISCLAIMER
 * This script is provided "as-is" for internal use at University of Extremadura. No warranties, express or implied, are 
 * provided. Any modifications or adaptations are not covered under this disclaimer.
 *
 * @LINK
 * https://github.com/n7rc/OpsHostGuard
 */

function openPrintPreview() {
    function getTableContentBydashboard(dashboard) {
        return document.querySelectorAll('h2')[dashboard].nextElementSibling.outerHTML;
    }

    // Get the content of the tables
    var summaryTable = getTableContentBydashboard(0);
    var failedPowerOnTable = getTableContentBydashboard(1);
    var failedShutdownTable = getTableContentBydashboard(2);

    // Set the report version and date
    var version = "1.0";
    var reportDate = new Date().toLocaleDateString();

    // Open a new window for the print preview
    var printWindow = window.open('', '_blank', 'width=800,height=600');

    // Styles for the print preview
    var styles = `
        <style>
            body {
                font-family: Arial, sans-serif;
                color: black;
            }
            h1, h2 {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                color: black;
                border-bottom: 1px solid #ddd;
                padding-bottom: 10px;
            }
            table {
                width: 100%;
                border-collapse: collapse;
                margin-bottom: 20px;
            }
            table th, table td {
                border: 1px solid black;
                padding: 10px;
                text-align: left;
            }
            table th {
                background-color: #f0f0f0;
                color: black;
            }
            .no-print {
                display: none;
            }
            .version-Info {
                font-size: 0.8em;
                color: #666;
                text-align: right;
                margin-top: 20px;
                font-family: 'Roboto', sans-serif;
            }
        </style>`;

    // HTML content for the print preview
    var printContent = `
        <html>
        <head>
            <title>Print Preview</title>
            ${styles}
        </head>
        <body>
            <div class="container">
                <h1>Daily Classroom Hosts Report - Print Preview</h1>
                <h2>General Summary</h2>
                ${summaryTable}
                <h2>Hosts Failed to Power On</h2>
                ${failedPowerOnTable}
                <h2>Hosts Failed to Shutdown</h2>
                ${failedShutdownTable}
                <p class="version-Info">[Version: ${version} - Date: ${reportDate}]</p>
            </div>
            <button id="print-btn" onclick="window.print();">Print Report</button>
        </body>
        </html>`;

    // Write the content in the new window
    printWindow.document.open();
    printWindow.document.write(printContent);
    printWindow.document.close();
}


function generatePDF() {
    // Select the content to export, ignoring elements with the 'no-export' class
    var content = document.querySelector('.exportable-content');

    // Clone the content to avoid modifying the original content in the DOM
    var clone = content.cloneNode(true);

    // Remove elements marked as 'no-export' to exclude them from the PDF
    clone.querySelectorAll('.no-export').forEach(el => el.remove());

    // Configure the PDF settings, including filename and appearance
    var fileDate = new Date().toISOString().split('T')[0].replace(/-/g, '');

    var opt = {
        margin: [0.5, 0],                           // Define PDF margins
        filename: `${fileDate}-HostsReport.pdf`,  // Filename
        image: { type: 'jpeg', quality: 0.98 },     // Define image quality for the PDF
        html2canvas: { scale: 4, logging: true, useCORS: true }, // Canvas settings for better clarity
        jsPDF: { unit: 'in', format: 'letter', orientation: 'portrait' } // PDF configuration: letter size, portrait orientation
    };

    // Ensure the 'html2pdf' library is loaded and available for use
    if (typeof html2pdf === 'undefined') {
        console.Error('html2pdf is not defined. Make sure the library is included.');
        return;
    }

    // Generate the PDF from the cloned content and handle any Errors
    html2pdf().from(clone).set(opt).save().catch(err => console.Error(err));
}

function generateInventoryPDF() {
    // Select the specific container for hardware inventory in hardware_inventory_report.php
    const content = document.querySelector('.exportable-content');

    // Verify that the correct container was selected
    if (!content) {
        console.Error("Error: el contenedor de 'exportable-content' no se encontró en hardware_inventory_report.php.");
        return;
    }

    // Clone the content to work on a copy without modifying the original
    const clone = content.cloneNode(true);

    // Remove elements marked with 'no-export' to ensure they aren't included in the PDF
    clone.querySelectorAll('.no-export').forEach(el => el.remove());

    // Get the current date formatted as YYYYMMDD to use in the filename
    const fileDate = new Date().toISOString().split('T')[0].replace(/-/g, '');

    // Configure the PDF options, including margins, filename, and page format
    const opt = {
        margin: [0.5, 0],                        // Set margins for the PDF
        filename: `${fileDate}-HardwareInventoryReport.pdf`,  // Use date-based filename
        image: { type: 'jpeg', quality: 0.98 },  // Set image quality for the PDF
        html2canvas: {
            scale: 2,                            // Set scale for better image clarity
            logging: true,                       // Enable logging for troubleshooting
            useCORS: true,                       // Allow cross-origin requests for images
            scrollY: 0                           // Prevent issues with page scrolling
        },
        jsPDF: {
            unit: 'in',                          // Use inches as the measurement unit
            format: 'a3',                        // Use A3 format for larger content
            orientation: 'landscape'             // Landscape orientation for wider reports
        }
    };

    // Check if the 'html2pdf' library is loaded and available for use
    if (typeof html2pdf === 'undefined') {
        console.Error('html2pdf is not defined. Make sure the library is included.');
        return;
    }

    // Generate the PDF from the cloned content and handle any Errors
    html2pdf().from(clone).set(opt).save().catch(err => console.Error("Error al generar PDF:", err));
}

// Function to filter table rows based on host and (optionally) event type
function filterTable(hostFilter, eventType = null) {
    const rows = document.querySelectorAll("table tr");

    rows.forEach((row, index) => {
        if (index === 0) return; // Skip the header row

        const host = row.querySelector("td:first-child");
        const status = row.querySelector("td:last-child");

        if (host) {
            const hostMatch = (hostFilter === "all" || host.textContent.includes(hostFilter));
            let eventTypeMatch = true;

            // Apply event type filter only if provided
            if (eventType) {
                eventTypeMatch = (eventType === "all" || (status && status.textContent.includes(eventType)));
            }

            // Show the row only if both filters (when applicable) match
            row.style.display = (hostMatch && eventTypeMatch) ? "" : "none";
        }
    });
}

// Filter function for all hosts in standar_report.php
function applyFiltersDashboard() {
    const hostFilter = document.getElementById("hostFilter").value || "all";
    const eventType = document.getElementById("eventType").value || "all";

    // Apply both host and eventType filters to the dashboard table
    filterTable(hostFilter, eventType);
}

// Filter function for powered-on hosts in hardware_inventory_report.php
function applyFiltersHardwareInventory() {
    const hostFilter = document.getElementById("hostFilter").value || "all";

    // Apply only the host filter to the hardwareInventory table
    filterTable(hostFilter);
}

// Reset filters to their default values and show all rows
function resetFilters(isDashboard = false) {
    document.getElementById("hostFilter").value = "all";

    // Reset eventType filter only for dashboard
    if (isDashboard) {
        document.getElementById("eventType").value = "all";
    }

    // Show all rows in the relevant table
    const rows = document.querySelectorAll("table tr");
    rows.forEach(row => {
        row.style.display = ""; // Make all rows visible again
    });
}
