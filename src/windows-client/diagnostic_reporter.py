#!/usr/bin/env python3
"""
Automated Reporting and Visualization Framework
AI Image Generation Demo - Enhanced Framework

Generates detailed diagnostic reports in multiple formats (JSON, HTML, Markdown),
provides performance comparison charts, historical trends, and automated remediation recommendations.
"""

import os
import json
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Dict, Any, List, Optional, Union
from dataclasses import dataclass, asdict
import base64
from io import BytesIO

from diagnostic_config import ReportFormat, get_config
from diagnostic_storage import get_diagnostic_storage

@dataclass
class ReportSection:
    """Report section data structure"""
    title: str
    content: str
    data: Dict[str, Any]
    section_type: str  # summary, details, chart, table, recommendations

@dataclass
class DiagnosticReport:
    """Complete diagnostic report structure"""
    report_id: str
    generation_time: float
    platform_type: str
    run_id: str
    overall_status: str
    executive_summary: str
    sections: List[ReportSection]
    metadata: Dict[str, Any]

class ChartGenerator:
    """Generate performance charts and visualizations"""
    
    def __init__(self):
        self.charts_available = self._check_chart_dependencies()
    
    def _check_chart_dependencies(self) -> bool:
        """Check if chart generation dependencies are available"""
        try:
            import matplotlib
            import matplotlib.pyplot as plt
            matplotlib.use('Agg')  # Non-interactive backend
            return True
        except ImportError:
            return False
    
    def generate_performance_trend_chart(self, trend_data: List[Dict[str, Any]], 
                                       metric_name: str, output_path: str) -> bool:
        """Generate performance trend chart"""
        if not self.charts_available:
            return False
        
        try:
            import matplotlib.pyplot as plt
            import matplotlib.dates as mdates
            
            # Extract data
            timestamps = [datetime.fromtimestamp(item['timestamp']) for item in trend_data]
            values = [item['metric_value'] for item in trend_data]
            
            if not timestamps or not values:
                return False
            
            # Create chart
            fig, ax = plt.subplots(figsize=(12, 6))
            ax.plot(timestamps, values, marker='o', linewidth=2, markersize=4)
            
            ax.set_title(f'Performance Trend: {metric_name}', fontsize=14, fontweight='bold')
            ax.set_xlabel('Time', fontsize=12)
            ax.set_ylabel(f'{metric_name}', fontsize=12)
            
            # Format x-axis
            ax.xaxis.set_major_formatter(mdates.DateFormatter('%m/%d %H:%M'))
            ax.xaxis.set_major_locator(mdates.HourLocator(interval=6))
            plt.xticks(rotation=45)
            
            # Grid and styling
            ax.grid(True, alpha=0.3)
            plt.tight_layout()
            
            # Save chart
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            
            return True
        except Exception as e:
            print(f"Error generating chart: {e}")
            return False
    
    def generate_test_success_chart(self, success_data: Dict[str, Dict[str, Any]], 
                                  output_path: str) -> bool:
        """Generate test success rate chart"""
        if not self.charts_available:
            return False
        
        try:
            import matplotlib.pyplot as plt
            
            test_names = list(success_data.keys())
            success_rates = [data['success_rate'] for data in success_data.values()]
            
            if not test_names:
                return False
            
            # Create horizontal bar chart
            fig, ax = plt.subplots(figsize=(10, max(6, len(test_names) * 0.5)))
            
            bars = ax.barh(test_names, success_rates, color='lightblue', edgecolor='navy', alpha=0.7)
            
            # Color bars based on success rate
            for i, (bar, rate) in enumerate(zip(bars, success_rates)):
                if rate >= 90:
                    bar.set_color('lightgreen')
                elif rate >= 70:
                    bar.set_color('orange')
                else:
                    bar.set_color('lightcoral')
            
            ax.set_title('Test Success Rates (Last 30 Days)', fontsize=14, fontweight='bold')
            ax.set_xlabel('Success Rate (%)', fontsize=12)
            ax.set_xlim(0, 100)
            
            # Add percentage labels
            for i, rate in enumerate(success_rates):
                ax.text(rate + 1, i, f'{rate:.1f}%', va='center', fontsize=10)
            
            plt.tight_layout()
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            
            return True
        except Exception as e:
            print(f"Error generating success chart: {e}")
            return False
    
    def generate_resource_usage_chart(self, resource_data: List[Dict[str, Any]], 
                                    output_path: str) -> bool:
        """Generate system resource usage chart"""
        if not self.charts_available:
            return False
        
        try:
            import matplotlib.pyplot as plt
            
            timestamps = [datetime.fromtimestamp(item['timestamp']) for item in resource_data]
            cpu_usage = [item['cpu_percent'] for item in resource_data]
            memory_usage = [item['memory_percent'] for item in resource_data]
            
            if not timestamps:
                return False
            
            # Create subplots
            fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8), sharex=True)
            
            # CPU usage
            ax1.plot(timestamps, cpu_usage, color='blue', linewidth=2, label='CPU Usage')
            ax1.set_ylabel('CPU Usage (%)', fontsize=12)
            ax1.set_title('System Resource Usage During Diagnostic', fontsize=14, fontweight='bold')
            ax1.grid(True, alpha=0.3)
            ax1.legend()
            ax1.set_ylim(0, 100)
            
            # Memory usage
            ax2.plot(timestamps, memory_usage, color='red', linewidth=2, label='Memory Usage')
            ax2.set_ylabel('Memory Usage (%)', fontsize=12)
            ax2.set_xlabel('Time', fontsize=12)
            ax2.grid(True, alpha=0.3)
            ax2.legend()
            ax2.set_ylim(0, 100)
            
            plt.tight_layout()
            plt.savefig(output_path, dpi=150, bbox_inches='tight')
            plt.close()
            
            return True
        except Exception as e:
            print(f"Error generating resource chart: {e}")
            return False
    
    def chart_to_base64(self, chart_path: str) -> str:
        """Convert chart to base64 for embedding in HTML"""
        try:
            with open(chart_path, 'rb') as f:
                chart_data = f.read()
            return base64.b64encode(chart_data).decode('utf-8')
        except Exception:
            return ""

class HTMLReportGenerator:
    """Generate HTML reports with charts and styling"""
    
    def __init__(self):
        self.chart_generator = ChartGenerator()
    
    def generate_html_report(self, report: DiagnosticReport, output_path: str) -> bool:
        """Generate complete HTML report"""
        try:
            html_content = self._build_html_content(report)
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(html_content)
            
            return True
        except Exception as e:
            print(f"Error generating HTML report: {e}")
            return False
    
    def _build_html_content(self, report: DiagnosticReport) -> str:
        """Build complete HTML content"""
        # HTML template with embedded CSS
        html_template = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI Image Generation Diagnostic Report</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 {
            margin: 0;
            font-size: 2.5em;
            font-weight: 300;
        }
        .header .subtitle {
            margin-top: 10px;
            font-size: 1.2em;
            opacity: 0.9;
        }
        .status-badge {
            display: inline-block;
            padding: 8px 16px;
            border-radius: 20px;
            font-weight: bold;
            margin-top: 15px;
        }
        .status-ready { background-color: #4CAF50; color: white; }
        .status-not-ready { background-color: #f44336; color: white; }
        .status-warning { background-color: #ff9800; color: white; }
        .content {
            padding: 30px;
        }
        .executive-summary {
            background-color: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin-bottom: 30px;
            border-radius: 0 4px 4px 0;
        }
        .section {
            margin-bottom: 30px;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            overflow: hidden;
        }
        .section-header {
            background-color: #f8f9fa;
            padding: 15px 20px;
            border-bottom: 1px solid #e0e0e0;
            font-weight: bold;
            font-size: 1.2em;
        }
        .section-content {
            padding: 20px;
        }
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 20px 0;
        }
        .metric-card {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            text-align: center;
            border: 1px solid #e0e0e0;
        }
        .metric-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        .metric-label {
            color: #666;
            font-size: 0.9em;
            margin-top: 5px;
        }
        .test-result {
            display: flex;
            align-items: center;
            padding: 10px 0;
            border-bottom: 1px solid #f0f0f0;
        }
        .test-status {
            width: 80px;
            text-align: center;
            font-weight: bold;
            border-radius: 4px;
            padding: 4px 8px;
            margin-right: 15px;
        }
        .test-pass { background-color: #4CAF50; color: white; }
        .test-fail { background-color: #f44336; color: white; }
        .test-details {
            flex: 1;
        }
        .fix-commands {
            background-color: #fff3cd;
            border: 1px solid #ffeaa7;
            border-radius: 4px;
            padding: 10px;
            margin-top: 10px;
        }
        .fix-command {
            font-family: 'Courier New', monospace;
            background-color: #f8f9fa;
            padding: 5px 8px;
            border-radius: 3px;
            margin: 5px 0;
            border-left: 3px solid #667eea;
        }
        .chart-container {
            text-align: center;
            margin: 20px 0;
        }
        .chart-container img {
            max-width: 100%;
            height: auto;
            border-radius: 4px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .recommendations {
            background-color: #e8f5e8;
            border: 1px solid #4CAF50;
            border-radius: 8px;
            padding: 20px;
            margin-top: 20px;
        }
        .footer {
            background-color: #f8f9fa;
            padding: 20px;
            text-align: center;
            color: #666;
            font-size: 0.9em;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f8f9fa;
            font-weight: bold;
        }
        .trend-indicator {
            font-weight: bold;
        }
        .trend-up { color: #4CAF50; }
        .trend-down { color: #f44336; }
        .trend-stable { color: #ff9800; }
    </style>
</head>
<body>
    <div class="container">
        {header}
        <div class="content">
            {executive_summary}
            {sections}
            {recommendations}
        </div>
        {footer}
    </div>
</body>
</html>
        """
        
        # Build components
        header = self._build_header(report)
        executive_summary = self._build_executive_summary(report)
        sections = self._build_sections(report)
        recommendations = self._build_recommendations(report)
        footer = self._build_footer(report)
        
        return html_template.format(
            header=header,
            executive_summary=executive_summary,
            sections=sections,
            recommendations=recommendations,
            footer=footer
        )
    
    def _build_header(self, report: DiagnosticReport) -> str:
        """Build report header"""
        status_class = "status-ready" if report.overall_status == "READY" else "status-not-ready"
        generation_time = datetime.fromtimestamp(report.generation_time).strftime("%Y-%m-%d %H:%M:%S UTC")
        
        return f"""
        <div class="header">
            <h1>AI Image Generation Diagnostic Report</h1>
            <div class="subtitle">Platform: {report.platform_type.upper()} | Generated: {generation_time}</div>
            <div class="status-badge {status_class}">{report.overall_status}</div>
        </div>
        """
    
    def _build_executive_summary(self, report: DiagnosticReport) -> str:
        """Build executive summary section"""
        return f"""
        <div class="executive-summary">
            <h2>Executive Summary</h2>
            <p>{report.executive_summary}</p>
        </div>
        """
    
    def _build_sections(self, report: DiagnosticReport) -> str:
        """Build all report sections"""
        sections_html = ""
        
        for section in report.sections:
            section_content = ""
            
            if section.section_type == "summary":
                section_content = self._build_summary_section(section)
            elif section.section_type == "details":
                section_content = self._build_details_section(section)
            elif section.section_type == "chart":
                section_content = self._build_chart_section(section)
            elif section.section_type == "table":
                section_content = self._build_table_section(section)
            else:
                section_content = f"<p>{section.content}</p>"
            
            sections_html += f"""
            <div class="section">
                <div class="section-header">{section.title}</div>
                <div class="section-content">
                    {section_content}
                </div>
            </div>
            """
        
        return sections_html
    
    def _build_summary_section(self, section: ReportSection) -> str:
        """Build summary metrics section"""
        metrics = section.data.get('metrics', {})
        
        metrics_html = '<div class="metrics-grid">'
        for key, value in metrics.items():
            metrics_html += f"""
            <div class="metric-card">
                <div class="metric-value">{value}</div>
                <div class="metric-label">{key.replace('_', ' ').title()}</div>
            </div>
            """
        metrics_html += '</div>'
        
        return f"<p>{section.content}</p>{metrics_html}"
    
    def _build_details_section(self, section: ReportSection) -> str:
        """Build detailed test results section"""
        test_results = section.data.get('test_results', {})
        
        results_html = ""
        for test_name, result in test_results.items():
            status_class = "test-pass" if result['status'] == "PASS" else "test-fail"
            
            results_html += f"""
            <div class="test-result">
                <div class="test-status {status_class}">{result['status']}</div>
                <div class="test-details">
                    <strong>{test_name}</strong><br>
                    {result['message']}
                    <small style="color: #666;"> (Duration: {result.get('duration', 0):.3f}s)</small>
            """
            
            if result.get('fix_commands'):
                results_html += '<div class="fix-commands"><strong>Fix Commands:</strong>'
                for cmd in result['fix_commands']:
                    results_html += f'<div class="fix-command">{cmd}</div>'
                results_html += '</div>'
            
            results_html += "</div></div>"
        
        return results_html
    
    def _build_chart_section(self, section: ReportSection) -> str:
        """Build chart section"""
        chart_data = section.data.get('chart_base64', '')
        if chart_data:
            return f"""
            <div class="chart-container">
                <img src="data:image/png;base64,{chart_data}" alt="{section.title}">
            </div>
            <p>{section.content}</p>
            """
        else:
            return f"<p>{section.content}</p><p><em>Chart generation not available</em></p>"
    
    def _build_table_section(self, section: ReportSection) -> str:
        """Build table section"""
        table_data = section.data.get('table_data', {})
        headers = table_data.get('headers', [])
        rows = table_data.get('rows', [])
        
        if not headers or not rows:
            return f"<p>{section.content}</p>"
        
        table_html = "<table><thead><tr>"
        for header in headers:
            table_html += f"<th>{header}</th>"
        table_html += "</tr></thead><tbody>"
        
        for row in rows:
            table_html += "<tr>"
            for cell in row:
                table_html += f"<td>{cell}</td>"
            table_html += "</tr>"
        
        table_html += "</tbody></table>"
        
        return f"<p>{section.content}</p>{table_html}"
    
    def _build_recommendations(self, report: DiagnosticReport) -> str:
        """Build recommendations section"""
        recommendations = report.metadata.get('recommendations', [])
        
        if not recommendations:
            return ""
        
        rec_html = '<div class="recommendations"><h3>Recommendations</h3><ul>'
        for rec in recommendations:
            rec_html += f"<li>{rec}</li>"
        rec_html += '</ul></div>'
        
        return rec_html
    
    def _build_footer(self, report: DiagnosticReport) -> str:
        """Build report footer"""
        return f"""
        <div class="footer">
            <p>Report ID: {report.report_id} | Generated by AI Image Generation Enhanced Diagnostic Framework</p>
            <p>For technical support, refer to the project documentation or contact your system administrator.</p>
        </div>
        """

class MarkdownReportGenerator:
    """Generate Markdown reports"""
    
    def generate_markdown_report(self, report: DiagnosticReport, output_path: str) -> bool:
        """Generate complete Markdown report"""
        try:
            markdown_content = self._build_markdown_content(report)
            
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(markdown_content)
            
            return True
        except Exception as e:
            print(f"Error generating Markdown report: {e}")
            return False
    
    def _build_markdown_content(self, report: DiagnosticReport) -> str:
        """Build complete Markdown content"""
        generation_time = datetime.fromtimestamp(report.generation_time).strftime("%Y-%m-%d %H:%M:%S UTC")
        
        content = f"""# AI Image Generation Diagnostic Report

**Platform:** {report.platform_type.upper()}  
**Status:** {report.overall_status}  
**Generated:** {generation_time}  
**Report ID:** {report.report_id}

---

## Executive Summary

{report.executive_summary}

---

"""
        
        # Add sections
        for section in report.sections:
            content += f"## {section.title}\n\n"
            content += f"{section.content}\n\n"
            
            if section.section_type == "table" and section.data.get('table_data'):
                content += self._build_markdown_table(section.data['table_data'])
            elif section.section_type == "summary" and section.data.get('metrics'):
                content += self._build_markdown_metrics(section.data['metrics'])
            
            content += "\n---\n\n"
        
        # Add recommendations
        recommendations = report.metadata.get('recommendations', [])
        if recommendations:
            content += "## Recommendations\n\n"
            for rec in recommendations:
                content += f"- {rec}\n"
            content += "\n---\n\n"
        
        # Add footer
        content += f"""## Report Information

- **Report ID:** {report.report_id}
- **Generation Time:** {generation_time}
- **Platform Type:** {report.platform_type}
- **Framework:** AI Image Generation Enhanced Diagnostic Framework

For technical support, refer to the project documentation.
"""
        
        return content
    
    def _build_markdown_table(self, table_data: Dict[str, Any]) -> str:
        """Build Markdown table"""
        headers = table_data.get('headers', [])
        rows = table_data.get('rows', [])
        
        if not headers or not rows:
            return ""
        
        # Table header
        table_md = "| " + " | ".join(headers) + " |\n"
        table_md += "| " + " | ".join(["---"] * len(headers)) + " |\n"
        
        # Table rows
        for row in rows:
            table_md += "| " + " | ".join(str(cell) for cell in row) + " |\n"
        
        return table_md + "\n"
    
    def _build_markdown_metrics(self, metrics: Dict[str, Any]) -> str:
        """Build Markdown metrics list"""
        metrics_md = ""
        for key, value in metrics.items():
            metrics_md += f"- **{key.replace('_', ' ').title()}:** {value}\n"
        return metrics_md + "\n"

class DiagnosticReporter:
    """Main diagnostic reporting coordinator"""
    
    def __init__(self):
        self.config = get_config()
        self.storage = get_diagnostic_storage()
        self.chart_generator = ChartGenerator()
        self.html_generator = HTMLReportGenerator()
        self.markdown_generator = MarkdownReportGenerator()
        
        # Ensure output directory exists
        report_dir = Path(self.config.reporting.output_directory)
        report_dir.mkdir(parents=True, exist_ok=True)
    
    def generate_comprehensive_report(self, run_id: str, platform_type: str,
                                    results: Dict[str, Any], metrics: Dict[str, Any]) -> Dict[str, str]:
        """Generate comprehensive report in all configured formats"""
        
        # Build report data
        report = self._build_diagnostic_report(run_id, platform_type, results, metrics)
        
        # Generate reports in requested formats
        generated_files = {}
        output_formats = self.config.reporting.output_formats
        
        base_filename = f"diagnostic_report_{run_id}_{int(time.time())}"
        report_dir = Path(self.config.reporting.output_directory)
        
        for format_type in output_formats:
            if format_type == ReportFormat.JSON:
                json_path = report_dir / f"{base_filename}.json"
                if self._generate_json_report(report, json_path):
                    generated_files['json'] = str(json_path)
            
            elif format_type == ReportFormat.HTML:
                html_path = report_dir / f"{base_filename}.html"
                if self.html_generator.generate_html_report(report, html_path):
                    generated_files['html'] = str(html_path)
            
            elif format_type == ReportFormat.MARKDOWN:
                md_path = report_dir / f"{base_filename}.md"
                if self.markdown_generator.generate_markdown_report(report, md_path):
                    generated_files['markdown'] = str(md_path)
        
        return generated_files
    
    def _build_diagnostic_report(self, run_id: str, platform_type: str,
                               results: Dict[str, Any], metrics: Dict[str, Any]) -> DiagnosticReport:
        """Build comprehensive diagnostic report data"""
        
        # Generate executive summary
        executive_summary = self._generate_executive_summary(results, metrics, platform_type)
        
        # Build report sections
        sections = []
        
        # Summary section
        sections.append(self._build_summary_section(results, metrics))
        
        # Detailed test results
        sections.append(self._build_test_details_section(results))
        
        # Performance metrics
        if metrics:
            sections.append(self._build_performance_section(metrics))
        
        # System information
        if metrics.get('system'):
            sections.append(self._build_system_section(metrics['system']))
        
        # Trends and comparisons (if historical data available)
        trend_section = self._build_trend_section(platform_type)
        if trend_section:
            sections.append(trend_section)
        
        # Generate recommendations
        recommendations = self._generate_recommendations(results, metrics, platform_type)
        
        return DiagnosticReport(
            report_id=f"{run_id}_{int(time.time())}",
            generation_time=time.time(),
            platform_type=platform_type,
            run_id=run_id,
            overall_status=results.get('overall_status', 'UNKNOWN'),
            executive_summary=executive_summary,
            sections=sections,
            metadata={'recommendations': recommendations}
        )
    
    def _generate_executive_summary(self, results: Dict[str, Any], 
                                  metrics: Dict[str, Any], platform_type: str) -> str:
        """Generate executive summary"""
        status = results.get('overall_status', 'UNKNOWN')
        total_tests = results.get('total_tests', 0)
        passed_tests = results.get('passed_tests', 0)
        duration = results.get('total_duration', 0)
        
        summary = f"Diagnostic completed for {platform_type.upper()} platform with {status} status. "
        summary += f"Executed {total_tests} tests with {passed_tests} passing "
        summary += f"({(passed_tests/total_tests*100):.1f}% success rate) in {duration:.1f} seconds."
        
        if status == "READY":
            summary += " System is ready for AI image generation operations."
        else:
            failed_tests = total_tests - passed_tests
            summary += f" {failed_tests} test(s) failed and require attention before proceeding."
        
        # Add performance insight
        if metrics.get('performance'):
            perf_data = metrics['performance']
            if 'generation_time' in perf_data:
                gen_time = perf_data['generation_time']
                summary += f" Performance test completed in {gen_time:.1f} seconds."
        
        return summary
    
    def _build_summary_section(self, results: Dict[str, Any], metrics: Dict[str, Any]) -> ReportSection:
        """Build summary metrics section"""
        summary_metrics = {
            'total_tests': results.get('total_tests', 0),
            'passed_tests': results.get('passed_tests', 0),
            'failed_tests': results.get('total_tests', 0) - results.get('passed_tests', 0),
            'success_rate': f"{(results.get('passed_tests', 0) / max(results.get('total_tests', 1), 1) * 100):.1f}%",
            'total_duration': f"{results.get('total_duration', 0):.2f}s"
        }
        
        if metrics.get('system'):
            system_data = metrics['system']
            summary_metrics.update({
                'cpu_usage': f"{system_data.get('cpu_percent', 0):.1f}%",
                'memory_usage': f"{system_data.get('memory_percent', 0):.1f}%",
                'platform': system_data.get('platform_type', 'Unknown')
            })
        
        content = "Key diagnostic metrics and system performance indicators."
        
        return ReportSection(
            title="Diagnostic Summary",
            content=content,
            data={'metrics': summary_metrics},
            section_type="summary"
        )
    
    def _build_test_details_section(self, results: Dict[str, Any]) -> ReportSection:
        """Build detailed test results section"""
        test_results = results.get('test_results', {})
        
        content = f"Detailed results for all {len(test_results)} diagnostic tests."
        
        return ReportSection(
            title="Test Results Details",
            content=content,
            data={'test_results': test_results},
            section_type="details"
        )
    
    def _build_performance_section(self, metrics: Dict[str, Any]) -> ReportSection:
        """Build performance metrics section"""
        perf_data = metrics.get('performance', {})
        
        content = "Performance metrics collected during diagnostic execution."
        
        # Create performance table
        table_data = {
            'headers': ['Metric', 'Value', 'Unit', 'Status'],
            'rows': []
        }
        
        for metric_name, value in perf_data.items():
            if isinstance(value, (int, float)):
                status = "Good"
                unit = "ms" if 'time' in metric_name else ""
                table_data['rows'].append([metric_name, f"{value:.3f}", unit, status])
        
        return ReportSection(
            title="Performance Metrics",
            content=content,
            data={'table_data': table_data, 'metrics': perf_data},
            section_type="table"
        )
    
    def _build_system_section(self, system_data: Dict[str, Any]) -> ReportSection:
        """Build system information section"""
        content = "System configuration and resource utilization during diagnostic execution."
        
        # Create system info table
        table_data = {
            'headers': ['Component', 'Value', 'Status'],
            'rows': [
                ['CPU Usage', f"{system_data.get('cpu_percent', 0):.1f}%", "Normal"],
                ['Memory Usage', f"{system_data.get('memory_percent', 0):.1f}%", "Normal"],
                ['Available Memory', f"{system_data.get('memory_available', 0) / (1024**3):.1f} GB", "OK"],
                ['Disk Usage', f"{system_data.get('disk_usage', 0):.1f}%", "Normal"]
            ]
        }
        
        return ReportSection(
            title="System Information",
            content=content,
            data={'table_data': table_data},
            section_type="table"
        )
    
    def _build_trend_section(self, platform_type: str) -> Optional[ReportSection]:
        """Build trend analysis section if data available"""
        try:
            trend_data = self.storage.get_trend_analysis(30)
            
            if not trend_data.get('recent_runs'):
                return None
            
            content = "Historical performance trends and success rate analysis over the last 30 days."
            
            # Build trend table
            recent_runs = trend_data['recent_runs'][:10]  # Last 10 runs
            table_data = {
                'headers': ['Date', 'Status', 'Success Rate', 'Duration'],
                'rows': []
            }
            
            for run in recent_runs:
                run_date = datetime.fromtimestamp(run['timestamp']).strftime('%m/%d %H:%M')
                success_rate = f"{(run['passed_tests'] / max(run['total_tests'], 1) * 100):.1f}%"
                table_data['rows'].append([
                    run_date,
                    run['overall_status'],
                    success_rate,
                    f"{run['total_duration']:.1f}s"
                ])
            
            return ReportSection(
                title="Historical Trends",
                content=content,
                data={'table_data': table_data, 'trend_data': trend_data},
                section_type="table"
            )
        except Exception:
            return None
    
    def _generate_recommendations(self, results: Dict[str, Any], 
                                metrics: Dict[str, Any], platform_type: str) -> List[str]:
        """Generate automated recommendations"""
        recommendations = []
        
        # Test failure recommendations
        failed_tests = []
        for test_name, result in results.get('test_results', {}).items():
            if result.get('status') == 'FAIL':
                failed_tests.append(test_name)
        
        if failed_tests:
            recommendations.append(f"Address {len(failed_tests)} failed test(s): {', '.join(failed_tests)}")
        
        # Performance recommendations
        if metrics.get('system'):
            system_data = metrics['system']
            
            if system_data.get('cpu_percent', 0) > 80:
                recommendations.append("High CPU usage detected - consider closing other applications during testing")
            
            if system_data.get('memory_percent', 0) > 85:
                recommendations.append("High memory usage detected - ensure sufficient RAM is available")
        
        # Platform-specific recommendations
        if platform_type == 'intel':
            if 'Hardware Acceleration' in failed_tests:
                recommendations.append("Update Intel GPU drivers and verify DirectML installation")
        elif platform_type == 'snapdragon':
            if 'Hardware Acceleration' in failed_tests:
                recommendations.append("Verify NPU drivers and QNN provider installation")
        
        # General recommendations
        if not recommendations:
            if results.get('overall_status') == 'READY':
                recommendations.append("System is optimally configured for AI image generation")
            else:
                recommendations.append("Review failed tests and apply suggested fix commands")
        
        return recommendations
    
    def _generate_json_report(self, report: DiagnosticReport, output_path: Path) -> bool:
        """Generate JSON report"""
        try:
            report_data = asdict(report)
            with open(output_path, 'w', encoding='utf-8') as f:
                json.dump(report_data, f, indent=2, default=str)
            return True
        except Exception as e:
            print(f"Error generating JSON report: {e}")
            return False

# Global reporter instance
_diagnostic_reporter = None

def get_diagnostic_reporter() -> DiagnosticReporter:
    """Get global diagnostic reporter instance"""
    global _diagnostic_reporter
    if _diagnostic_reporter is None:
        _diagnostic_reporter = DiagnosticReporter()
    return _diagnostic_reporter

def generate_report(run_id: str, platform_type: str, 
                   results: Dict[str, Any], metrics: Dict[str, Any]) -> Dict[str, str]:
    """Generate diagnostic report using global reporter"""
    return get_diagnostic_reporter().generate_comprehensive_report(run_id, platform_type, results, metrics)