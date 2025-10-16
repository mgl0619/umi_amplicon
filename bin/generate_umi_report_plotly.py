#!/usr/bin/env python3
"""
Generate modern interactive UMI QC HTML report using Plotly.

This script creates a publication-quality, interactive HTML report with:
- Interactive Plotly visualizations
- Modern responsive design
- Hover tooltips and zoom capabilities
- Self-contained single HTML file
"""

import argparse
import json
import sys
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any

import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import numpy as np


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='Generate interactive UMI QC HTML report with Plotly'
    )
    parser.add_argument(
        '--pre-dedup-txt',
        type=str,
        required=False,
        help='Path to pre-deduplication metrics text file'
    )
    parser.add_argument(
        '--pre-dedup-json',
        type=str,
        required=False,
        help='Path to pre-deduplication metrics JSON file (for plot data)'
    )
    parser.add_argument(
        '--post-dedup-json',
        type=str,
        required=True,
        help='Path to post-deduplication metrics JSON file'
    )
    parser.add_argument(
        '--sample',
        type=str,
        required=True,
        help='Sample name'
    )
    parser.add_argument(
        '--output',
        type=str,
        required=True,
        help='Output HTML file path'
    )
    return parser.parse_args()


def parse_pre_dedup_txt(txt_file: str) -> Dict[str, Any]:
    """Parse pre-deduplication metrics from text file."""
    metrics = {}
    per_position_quality = []
    
    with open(txt_file, 'r') as f:
        lines = f.readlines()
    
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        
        # Parse basic statistics
        if 'Input reads:' in line:
            metrics['input_reads'] = int(line.split(':')[1].strip().replace(',', ''))
        elif 'Output reads:' in line:
            metrics['output_reads'] = int(line.split(':')[1].strip().replace(',', ''))
        elif 'Total reads analyzed:' in line:
            metrics['total_reads'] = int(line.split(':')[1].strip().replace(',', ''))
        elif 'Total UMIs:' in line:
            metrics['total_umis'] = int(line.split(':')[1].strip().replace(',', ''))
        elif 'Unique UMIs:' in line:
            metrics['unique_umis'] = int(line.split(':')[1].strip().replace(',', ''))
        elif 'UMI length:' in line:
            metrics['umi_length'] = int(line.split(':')[1].strip())
        
        # Parse diversity metrics
        elif 'Diversity ratio:' in line:
            metrics['diversity_ratio'] = float(line.split(':')[1].strip())
        elif 'Shannon entropy:' in line:
            metrics['shannon_entropy'] = float(line.split(':')[1].strip())
        elif 'Complexity score:' in line:
            metrics['complexity_score'] = float(line.split(':')[1].strip())
        
        # Parse collision metrics
        elif 'Starting molecules (n):' in line:
            metrics['starting_molecules'] = int(line.split(':')[1].strip().replace(',', ''))
        elif 'Expected num unique UMIs:' in line:
            metrics['expected_num_unique_umis'] = float(line.split(':')[1].strip())
        elif 'Expected num colliding pairs:' in line:
            metrics['expected_num_colliding_pairs'] = float(line.split(':')[1].strip())
        elif 'Expected fraction molecules colliding:' in line:
            # Parse both the fraction and percentage
            parts = line.split(':')[1].strip().split('(')
            metrics['expected_fraction_molecules_colliding'] = float(parts[0].strip())
        elif 'Probability of at least one UMI collision:' in line:
            metrics['prob_at_least_one_umi_collision'] = float(line.split(':')[1].strip())
        elif 'Expected duplicate rate for UMI before PCR (random collision):' in line:
            # Parse both the fraction and percentage
            parts = line.split(':')[1].strip().split('(')
            metrics['expected_duplicate_rate'] = float(parts[0].strip())
        elif 'Observed duplication rate (PCR + collision):' in line:
            # Parse both the fraction and percentage
            parts = line.split(':')[1].strip().split('(')
            metrics['observed_collision_rate'] = float(parts[0].strip())
        
        # Parse family size statistics
        elif 'Mean family size:' in line:
            metrics['mean_family_size'] = float(line.split(':')[1].strip())
        elif 'Median family size:' in line:
            metrics['median_family_size'] = int(line.split(':')[1].strip())
        elif 'Min family size:' in line:
            metrics['min_family_size'] = int(line.split(':')[1].strip())
        elif 'Max family size:' in line:
            metrics['max_family_size'] = int(line.split(':')[1].strip())
        elif 'Amplification ratio:' in line:
            metrics['amplification_ratio'] = float(line.split(':')[1].strip())
        
        # Parse singleton analysis
        elif 'Singleton count:' in line:
            metrics['singleton_count'] = int(line.split(':')[1].strip().replace(',', ''))
        elif 'Singleton rate:' in line:
            metrics['singleton_rate'] = float(line.split(':')[1].strip())
        
        # Parse quality metrics
        elif 'Mean UMI quality:' in line:
            metrics['mean_umi_quality'] = float(line.split(':')[1].strip())
        elif 'Min UMI quality:' in line:
            metrics['min_umi_quality'] = float(line.split(':')[1].strip())
        elif 'Max UMI quality:' in line:
            metrics['max_umi_quality'] = float(line.split(':')[1].strip())
        
        # Parse per-position quality
        elif 'Per-Position Quality Scores:' in line:
            i += 2  # Skip header line
            while i < len(lines):
                i += 1
                pos_line = lines[i].strip()
                if not pos_line or pos_line.startswith('-') or pos_line.startswith('Performance'):
                    break
                parts = pos_line.split()
                if len(parts) >= 4 and parts[0].isdigit():
                    per_position_quality.append({
                        'position': int(parts[0]),
                        'mean_quality': float(parts[1]),
                        'min_quality': float(parts[2]),
                        'max_quality': float(parts[3])
                    })
        
        # Parse performance metrics
        elif 'Success rate:' in line:
            metrics['success_rate'] = float(line.split(':')[1].strip())
        elif 'Specificity:' in line:
            metrics['specificity'] = float(line.split(':')[1].strip())
        
        i += 1
    
    if per_position_quality:
        metrics['per_position_quality'] = per_position_quality
    
    return metrics


def load_metrics(metrics_file: str) -> Dict[str, Any]:
    """Load metrics from JSON file."""
    with open(metrics_file, 'r') as f:
        data = json.load(f)
    
    # Extract metrics from MultiQC JSON structure
    if 'data' in data:
        sample_key = list(data['data'].keys())[0]
        metrics = data['data'][sample_key]
        
        # Add plot data if available
        if 'plot_data' in data:
            metrics['plot_data'] = data['plot_data']
        
        return metrics
    
    return data


def get_status_color(metric_name: str, value: float) -> str:
    """Get color based on metric value and thresholds."""
    thresholds = {
        'diversity_ratio': {'excellent': 0.7, 'good': 0.5, 'warning': 0.3},
        'complexity_score': {'excellent': 0.9, 'good': 0.7, 'warning': 0.5},
        'collision_rate': {'excellent': 0.01, 'good': 0.05, 'warning': 0.1, 'inverse': True},
        'singleton_rate': {'excellent': (0.2, 0.6), 'good': (0.1, 0.8), 'range': True},
        'mean_umi_quality': {'excellent': 30, 'good': 20, 'warning': 15},
    }
    
    if metric_name not in thresholds:
        return '#3b82f6'  # Default blue
    
    thresh = thresholds[metric_name]
    
    # Handle range-based thresholds
    if thresh.get('range'):
        if thresh['excellent'][0] <= value <= thresh['excellent'][1]:
            return '#10b981'  # Green
        elif thresh['good'][0] <= value <= thresh['good'][1]:
            return '#3b82f6'  # Blue
        else:
            return '#ef4444'  # Red
    
    # Handle inverse thresholds (lower is better)
    if thresh.get('inverse'):
        if value <= thresh['excellent']:
            return '#10b981'
        elif value <= thresh['good']:
            return '#3b82f6'
        elif value <= thresh['warning']:
            return '#f59e0b'
        else:
            return '#ef4444'
    
    # Handle normal thresholds (higher is better)
    if value >= thresh['excellent']:
        return '#10b981'
    elif value >= thresh['good']:
        return '#3b82f6'
    elif value >= thresh['warning']:
        return '#f59e0b'
    else:
        return '#ef4444'


def create_family_size_plot(metrics: Dict) -> go.Figure:
    """Create interactive family size distribution plot."""
    if 'plot_data' not in metrics or 'family_size_distribution' not in metrics['plot_data']:
        return None
    
    sample_key = list(metrics['plot_data']['family_size_distribution'].keys())[0]
    data = metrics['plot_data']['family_size_distribution'][sample_key]
    
    sizes = sorted([int(k) for k in data.keys()])
    counts = [data[str(s)] for s in sizes]
    
    fig = go.Figure()
    
    # Add bar chart
    fig.add_trace(go.Bar(
        x=sizes,
        y=counts,
        marker=dict(
            color=counts,
            colorscale='Viridis',
            showscale=True,
            colorbar=dict(title="Count")
        ),
        hovertemplate='<b>Family Size:</b> %{x}<br><b>Count:</b> %{y}<extra></extra>'
    ))
    
    fig.update_layout(
        title='UMI Family Size Distribution',
        xaxis_title='Family Size (reads per UMI)',
        yaxis_title='Number of UMIs',
        yaxis_type='log',
        template='plotly_white',
        hovermode='closest',
        height=500
    )
    
    return fig


def create_top_umis_plot(metrics: Dict) -> go.Figure:
    """Create interactive top UMIs bar chart."""
    if 'plot_data' not in metrics or 'top_umis' not in metrics['plot_data']:
        return None
    
    sample_key = list(metrics['plot_data']['top_umis'].keys())[0]
    data = metrics['plot_data']['top_umis'][sample_key]
    
    umis = list(data.keys())[:20]
    counts = [data[umi] for umi in umis]
    
    # Create color gradient
    colors = px.colors.sequential.Blues_r[:len(umis)]
    
    fig = go.Figure()
    
    fig.add_trace(go.Bar(
        x=umis,
        y=counts,
        marker=dict(color=colors),
        hovertemplate='<b>UMI:</b> %{x}<br><b>Count:</b> %{y}<extra></extra>'
    ))
    
    fig.update_layout(
        title='Top 20 Most Abundant UMIs',
        xaxis_title='UMI Sequence',
        yaxis_title='Read Count',
        template='plotly_white',
        xaxis_tickangle=-45,
        height=500
    )
    
    return fig


def create_quality_plot(metrics: Dict) -> go.Figure:
    """Create interactive UMI quality by position plot from text file data."""
    # First try to get per-position quality from parsed text file
    if 'per_position_quality' in metrics:
        per_pos_data = metrics['per_position_quality']
        
        positions = [d['position'] for d in per_pos_data]
        mean_qualities = [d['mean_quality'] for d in per_pos_data]
        min_qualities = [d['min_quality'] for d in per_pos_data]
        max_qualities = [d['max_quality'] for d in per_pos_data]
        
        # Color based on quality
        colors = ['#10b981' if q >= 30 else '#f59e0b' if q >= 20 else '#ef4444' for q in mean_qualities]
        
        fig = go.Figure()
        
        # Add shaded area for min-max range
        fig.add_trace(go.Scatter(
            x=positions + positions[::-1],
            y=max_qualities + min_qualities[::-1],
            fill='toself',
            fillcolor='rgba(59, 130, 246, 0.1)',
            line=dict(color='rgba(255,255,255,0)'),
            showlegend=True,
            name='Min-Max Range',
            hoverinfo='skip'
        ))
        
        # Add mean quality line
        fig.add_trace(go.Scatter(
            x=positions,
            y=mean_qualities,
            mode='lines+markers',
            line=dict(color='#3b82f6', width=3),
            marker=dict(size=10, color=colors, line=dict(width=2, color='white')),
            name='Mean Quality',
            hovertemplate='<b>Position:</b> %{x}<br><b>Mean Quality:</b> %{y:.2f}<extra></extra>'
        ))
        
        # Add quality threshold lines
        fig.add_hline(y=30, line_dash="dash", line_color="green", 
                      annotation_text="Excellent (Q30)", annotation_position="right")
        fig.add_hline(y=20, line_dash="dash", line_color="orange",
                      annotation_text="Good (Q20)", annotation_position="right")
        
        fig.update_layout(
            title='UMI Quality by Position (Mean with Min-Max Range)',
            xaxis_title='Position in UMI',
            yaxis_title='Phred Quality Score',
            template='plotly_white',
            yaxis_range=[0, 42],
            height=500,
            hovermode='x unified'
        )
        
        return fig
    
    # Fallback: Try JSON data if available
    elif 'plot_data' in metrics and 'umi_quality_by_position' in metrics['plot_data']:
        sample_key = list(metrics['plot_data']['umi_quality_by_position'].keys())[0]
        data = metrics['plot_data']['umi_quality_by_position'][sample_key]
        
        positions = sorted([int(k) for k in data.keys()])
        qualities = [data[str(p)] for p in positions]
        
        # Color based on quality
        colors = ['#10b981' if q >= 30 else '#f59e0b' if q >= 20 else '#ef4444' for q in qualities]
        
        fig = go.Figure()
        
        # Add line
        fig.add_trace(go.Scatter(
            x=positions,
            y=qualities,
            mode='lines+markers',
            line=dict(color='#3b82f6', width=3),
            marker=dict(size=10, color=colors, line=dict(width=2, color='white')),
            hovertemplate='<b>Position:</b> %{x}<br><b>Quality:</b> %{y:.2f}<extra></extra>'
        ))
        
        # Add quality threshold lines
        fig.add_hline(y=30, line_dash="dash", line_color="green", 
                      annotation_text="Excellent (Q30)", annotation_position="right")
        fig.add_hline(y=20, line_dash="dash", line_color="orange",
                      annotation_text="Good (Q20)", annotation_position="right")
        
        fig.update_layout(
            title='UMI Quality by Position',
            xaxis_title='Position in UMI',
            yaxis_title='Mean Phred Quality Score',
            template='plotly_white',
            yaxis_range=[0, 42],
            height=500
        )
        
        return fig
    
    return None


def create_metrics_gauge(metrics: Dict) -> go.Figure:
    """Create gauge charts for key metrics."""
    fig = make_subplots(
        rows=2, cols=3,
        specs=[[{'type': 'indicator'}, {'type': 'indicator'}, {'type': 'indicator'}],
               [{'type': 'indicator'}, {'type': 'indicator'}, {'type': 'indicator'}]],
        subplot_titles=('Diversity Ratio', 'Complexity Score', 'Mean UMI Quality',
                       'Singleton Rate', 'Collision Rate', 'Success Rate')
    )
    
    # Diversity Ratio
    div_ratio = metrics.get('diversity_ratio', 0)
    fig.add_trace(go.Indicator(
        mode="gauge+number",
        value=div_ratio,
        domain={'x': [0, 1], 'y': [0, 1]},
        gauge={
            'axis': {'range': [0, 1]},
            'bar': {'color': get_status_color('diversity_ratio', div_ratio)},
            'steps': [
                {'range': [0, 0.3], 'color': "lightgray"},
                {'range': [0.3, 0.5], 'color': "gray"},
                {'range': [0.5, 1], 'color': "lightgreen"}
            ],
            'threshold': {
                'line': {'color': "red", 'width': 4},
                'thickness': 0.75,
                'value': 0.7
            }
        }
    ), row=1, col=1)
    
    # Complexity Score
    complexity = metrics.get('complexity_score', 0)
    fig.add_trace(go.Indicator(
        mode="gauge+number",
        value=complexity,
        domain={'x': [0, 1], 'y': [0, 1]},
        gauge={
            'axis': {'range': [0, 1]},
            'bar': {'color': get_status_color('complexity_score', complexity)},
        }
    ), row=1, col=2)
    
    # Mean UMI Quality
    quality = metrics.get('mean_umi_quality', 0)
    fig.add_trace(go.Indicator(
        mode="gauge+number",
        value=quality,
        domain={'x': [0, 1], 'y': [0, 1]},
        gauge={
            'axis': {'range': [0, 42]},
            'bar': {'color': get_status_color('mean_umi_quality', quality)},
        }
    ), row=1, col=3)
    
    # Singleton Rate
    singleton = metrics.get('singleton_rate', 0)
    fig.add_trace(go.Indicator(
        mode="gauge+number",
        value=singleton,
        domain={'x': [0, 1], 'y': [0, 1]},
        gauge={
            'axis': {'range': [0, 1]},
            'bar': {'color': get_status_color('singleton_rate', singleton)},
        }
    ), row=2, col=1)
    
    # Collision Rate
    collision = metrics.get('collision_rate', 0)
    fig.add_trace(go.Indicator(
        mode="gauge+number",
        value=collision,
        domain={'x': [0, 1], 'y': [0, 1]},
        gauge={
            'axis': {'range': [0, 1]},
            'bar': {'color': get_status_color('collision_rate', collision)},
        }
    ), row=2, col=2)
    
    # Success Rate
    success = metrics.get('success_rate', 0)
    fig.add_trace(go.Indicator(
        mode="gauge+number",
        value=success,
        domain={'x': [0, 1], 'y': [0, 1]},
        gauge={
            'axis': {'range': [0, 1]},
            'bar': {'color': '#3b82f6'},
        }
    ), row=2, col=3)
    
    fig.update_layout(
        height=600,
        showlegend=False,
        template='plotly_white'
    )
    
    return fig


def create_summary_table(metrics: Dict) -> str:
    """Create HTML table with all metrics matching text file structure."""
    # Organize metrics to match the text file sections
    metric_groups = {
        'Extraction Statistics': [
            ('Total reads analyzed', metrics.get('total_reads', 0), '{:,}'),
            ('Total UMIs', metrics.get('total_umis', 0), '{:,}'),
            ('Unique UMIs', metrics.get('unique_umis', 0), '{:,}'),
            ('UMI length', metrics.get('umi_length', 0), '{}'),
        ],
        'UMI Diversity': [
            ('Diversity ratio', metrics.get('diversity_ratio', 0), '{:.4f}'),
            ('Shannon entropy', metrics.get('shannon_entropy', 0), '{:.4f}'),
            ('Complexity score', metrics.get('complexity_score', 0), '{:.4f}'),
        ],
        'UMI Collision Analysis (Birthday Problem)': [
            ('Starting molecules (n)', metrics.get('starting_molecules', 0), '{:,}'),
            ('Expected num unique UMIs', metrics.get('expected_num_unique_umis', 0), '{:.1f}'),
            ('Expected num colliding pairs', metrics.get('expected_num_colliding_pairs', 0), '{:.2f}'),
            ('Expected fraction molecules colliding', metrics.get('expected_fraction_molecules_colliding', 0), '{:.4f}'),
            ('Probability of at least one UMI collision', metrics.get('prob_at_least_one_umi_collision', 0), '{:.6f}'),
            ('Expected duplicate rate (random)', metrics.get('expected_duplicate_rate', 0), '{:.4f}'),
            ('Observed duplication rate (PCR + collision)', metrics.get('observed_collision_rate', 0), '{:.4f}'),
        ],
        'Family Size Statistics': [
            ('Mean family size', metrics.get('mean_family_size', 0), '{:.2f}'),
            ('Median family size', metrics.get('median_family_size', 0), '{:.0f}'),
            ('Min family size', metrics.get('min_family_size', 0), '{}'),
            ('Max family size', metrics.get('max_family_size', 0), '{}'),
            ('Amplification ratio', metrics.get('amplification_ratio', 0), '{:.2f}'),
        ],
        'Singleton Analysis': [
            ('Singleton count', metrics.get('singleton_count', 0), '{:,}'),
            ('Singleton rate', metrics.get('singleton_rate', 0), '{:.4f}'),
        ],
        'Quality Metrics': [
            ('Mean UMI quality', metrics.get('mean_umi_quality', 0), '{:.2f}'),
            ('Min UMI quality', metrics.get('min_umi_quality', 0), '{:.2f}'),
            ('Max UMI quality', metrics.get('max_umi_quality', 0), '{:.2f}'),
        ],
        'Performance Metrics': [
            ('Success rate', metrics.get('success_rate', 0), '{:.4f}'),
        ]
    }
    
    html = '<div class="metrics-grid">'
    
    for group_name, group_metrics in metric_groups.items():
        html += f'<div class="metric-group"><h3>{group_name}</h3><table class="metrics-table">'
        
        for name, value, fmt in group_metrics:
            # Handle N/A values
            if value == 'N/A':
                formatted_value = 'N/A'
            else:
                try:
                    formatted_value = fmt.format(value)
                except:
                    formatted_value = str(value)
            
            # Get color based on metric type
            color = '#3b82f6'  # Default blue
            if 'rate' in name.lower() or 'ratio' in name.lower():
                if value != 'N/A' and value > 0.8:
                    color = '#ef4444'  # Red for high rates
                elif value != 'N/A' and value > 0.5:
                    color = '#f59e0b'  # Orange for medium
                else:
                    color = '#10b981'  # Green for low
            
            html += f'''
            <tr>
                <td class="metric-name">{name}</td>
                <td class="metric-value" style="color: {color};">{formatted_value}</td>
            </tr>
            '''
        
        html += '</table></div>'
    
    html += '</div>'
    return html


def create_post_dedup_summary_table(metrics: Dict) -> str:
    """Create HTML table for post-deduplication metrics matching text file structure."""
    # Organize metrics to match the post-dedup text file sections
    metric_groups = {
        'DEDUPLICATION SUMMARY': [
            ('Total input reads', metrics.get('total_reads', 0), '{:,}'),
            ('Deduplicated reads (output)', metrics.get('deduplicated_reads', 0), '{:,}'),
            ('Duplicates removed', metrics.get('duplicates_removed', 0), '{:,}'),
            ('Deduplication rate', metrics.get('deduplication_rate_pct', 0), '{:.2f}%'),
            ('Duplication rate (fold)', metrics.get('duplication_rate', 0), '{:.2f}x'),
        ],
        'UMI FAMILY STATISTICS': [
            ('Unique UMI families', metrics.get('unique_umi_families', 0), '{:,}'),
            ('Average family size', metrics.get('avg_family_size', 0), '{:.2f}'),
            ('Median family size', metrics.get('median_family_size', 0), '{:.2f}'),
            ('Std dev family size', metrics.get('stdev_family_size', 0), '{:.2f}'),
            ('Min family size', metrics.get('min_family_size', 0), '{}'),
            ('Max family size', metrics.get('max_family_size', 0), '{}'),
            ('Singleton families', metrics.get('singleton_families', 0), '{:,}'),
            ('Singleton family rate', metrics.get('singleton_family_rate_pct', 0), '{:.2f}%'),
        ],
        'UMI ERROR CORRECTION & CLUSTERING': [
            ('UMI pairs compared', metrics.get('total_umi_pairs_compared', 0), '{:,}'),
            ('Mean edit distance', metrics.get('mean_edit_distance', 0), '{:.2f}'),
            ('Median edit distance', metrics.get('median_edit_distance', 0), '{:.2f}'),
            ('Max edit distance', metrics.get('max_edit_distance', 0), '{}'),
            ('UMI pairs clustered (≤1 edit)', metrics.get('umi_pairs_clustered', 0), '{:,}'),
            ('Error correction rate', metrics.get('error_correction_rate_pct', 0), '{:.2f}%'),
        ]
    }
    
    html = '<div class="metrics-grid">'
    
    for group_name, group_metrics in metric_groups.items():
        html += f'<div class="metric-group"><h3>{group_name}</h3><table class="metrics-table">'
        
        for name, value, fmt in group_metrics:
            try:
                formatted_value = fmt.format(value)
            except:
                formatted_value = str(value)
            
            # Get color based on metric type
            color = '#3b82f6'  # Default blue
            if 'deduplication rate' in name.lower() and value > 80:
                color = '#ef4444'  # Red for high dedup rate
            elif 'singleton' in name.lower() and 'rate' in name.lower() and value > 50:
                color = '#f59e0b'  # Orange for high singleton rate
            elif 'error correction rate' in name.lower() and value > 30:
                color = '#f59e0b'  # Orange for high error correction
            
            html += f'''
            <tr>
                <td class="metric-name">{name}</td>
                <td class="metric-value" style="color: {color};">{formatted_value}</td>
            </tr>
            '''
        
        html += '</table></div>'
    
    html += '</div>'
    return html


def create_pre_dedup_section(metrics: Dict) -> str:
    """Create post-UMI extraction section (before deduplication) with comprehensive metrics and visualizations."""
    if not metrics:
        return ""
    
    html = '<div class="section pre-dedup-section">'
    html += '<h2>📊 Section 1: Post-UMI Extraction Metrics (Before Deduplication)</h2>'
    
    # Add comprehensive metrics table using the updated create_summary_table function
    html += '<h3 style="margin-top: 2rem;">Summary Metrics</h3>'
    html += create_summary_table(metrics)
    
    # Add visualizations
    html += '<h3 style="margin-top: 2rem;">Interactive Visualizations</h3>'
    
    # 1. Per-position quality plot (using the improved version from create_quality_plot)
    quality_plot = create_quality_plot(metrics)
    if quality_plot:
        html += f'<div class="plot-container">{quality_plot.to_html(include_plotlyjs=False, div_id="pre_quality")}</div>'
    
    # 2. Family size distribution
    family_plot = create_family_size_plot(metrics)
    if family_plot:
        html += f'<div class="plot-container">{family_plot.to_html(include_plotlyjs=False, div_id="pre_family_size")}</div>'
    
    # 3. Top UMIs
    top_umis_plot = create_top_umis_plot(metrics)
    if top_umis_plot:
        html += f'<div class="plot-container">{top_umis_plot.to_html(include_plotlyjs=False, div_id="pre_top_umis")}</div>'
    
    # 4. Collision Analysis Bar Chart
    collision_data = {
        'Expected Duplicate Rate\n(Random Collision)': metrics.get('expected_duplicate_rate', 0),
        'Observed Duplication Rate\n(PCR + Collision)': metrics.get('observed_collision_rate', 0),
        'Expected Fraction\nMolecules Colliding': metrics.get('expected_fraction_molecules_colliding', 0)
    }
    
    fig = go.Figure(data=[
        go.Bar(
            x=list(collision_data.keys()), 
            y=list(collision_data.values()),
            marker_color=['#10b981', '#ef4444', '#f59e0b'],
            text=[f'{v:.4f}' for v in collision_data.values()],
            textposition='auto'
        )
    ])
    fig.update_layout(
        title='UMI Collision Analysis: Expected vs Observed',
        yaxis_title='Rate/Fraction',
        template='plotly_white',
        height=450,
        showlegend=False
    )
    html += f'<div class="plot-container">{fig.to_html(include_plotlyjs=False, div_id="pre_collision")}</div>'
    
    html += '</div>'
    
    return html


def generate_html_report(pre_dedup_metrics: Dict, post_dedup_metrics: Dict, sample: str, output_file: str):
    """Generate complete HTML report with Plotly visualizations."""
    
    # Create post-dedup plots
    family_size_plot = create_family_size_plot(post_dedup_metrics)
    top_umis_plot = create_top_umis_plot(post_dedup_metrics)
    quality_plot = create_quality_plot(post_dedup_metrics)
    
    # Convert plots to HTML
    plots_html = ""
    if family_size_plot:
        plots_html += f'<div class="plot-container">{family_size_plot.to_html(include_plotlyjs=False, div_id="family_size")}</div>'
    if top_umis_plot:
        plots_html += f'<div class="plot-container">{top_umis_plot.to_html(include_plotlyjs=False, div_id="top_umis")}</div>'
    if quality_plot:
        plots_html += f'<div class="plot-container">{quality_plot.to_html(include_plotlyjs=False, div_id="quality")}</div>'
    
    # Create pre-dedup section
    pre_dedup_section = create_pre_dedup_section(pre_dedup_metrics)
    
    # Create post-dedup metrics table using the dedicated post-dedup function
    metrics_table = create_post_dedup_summary_table(post_dedup_metrics)
    
    # Generate recommendations
    recommendations = generate_recommendations(post_dedup_metrics)
    
    # Create HTML
    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>UMI QC Report - {sample}</title>
    <script src="https://cdn.plot.ly/plotly-2.26.0.min.js"></script>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            line-height: 1.6;
            color: #1f2937;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 2rem;
        }}
        
        .container {{
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            overflow: hidden;
        }}
        
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 3rem 2rem;
            text-align: center;
        }}
        
        .header h1 {{
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
            font-weight: 700;
        }}
        
        .header .subtitle {{
            font-size: 1.2rem;
            opacity: 0.9;
        }}
        
        .content {{
            padding: 2rem;
        }}
        
        .section {{
            margin-bottom: 3rem;
        }}
        
        .section h2 {{
            font-size: 1.8rem;
            margin-bottom: 1.5rem;
            color: #667eea;
            border-bottom: 3px solid #667eea;
            padding-bottom: 0.5rem;
        }}
        
        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 1.5rem;
            margin-bottom: 2rem;
        }}
        
        .metric-group {{
            background: #f9fafb;
            border-radius: 12px;
            padding: 1.5rem;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }}
        
        .metric-group h3 {{
            font-size: 1.2rem;
            margin-bottom: 1rem;
            color: #4b5563;
        }}
        
        .metrics-table {{
            width: 100%;
            border-collapse: collapse;
        }}
        
        .metrics-table td {{
            padding: 0.75rem 0;
            border-bottom: 1px solid #e5e7eb;
        }}
        
        .metrics-table tr:last-child td {{
            border-bottom: none;
        }}
        
        .metric-name {{
            font-weight: 500;
            color: #6b7280;
        }}
        
        .metric-value {{
            text-align: right;
            font-weight: 700;
            font-size: 1.1rem;
        }}
        
        .plot-container {{
            margin-bottom: 2rem;
            background: white;
            border-radius: 12px;
            padding: 1rem;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
        }}
        
        .recommendations {{
            background: #fef3c7;
            border-left: 4px solid #f59e0b;
            padding: 1.5rem;
            border-radius: 8px;
        }}
        
        .recommendations h3 {{
            color: #92400e;
            margin-bottom: 1rem;
        }}
        
        .recommendations ul {{
            list-style-position: inside;
            color: #78350f;
        }}
        
        .recommendations li {{
            margin-bottom: 0.5rem;
        }}
        
        .footer {{
            text-align: center;
            padding: 2rem;
            color: #6b7280;
            font-size: 0.9rem;
            border-top: 1px solid #e5e7eb;
        }}
        
        @media print {{
            body {{
                background: white;
                padding: 0;
            }}
            .container {{
                box-shadow: none;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧬 UMI Quality Control Report</h1>
            <div class="subtitle">Sample: {sample}</div>
            <div class="subtitle">Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</div>
        </div>
        
        <div class="content">
            {pre_dedup_section}
            
            <div class="section post-dedup-section">
                <h2>📊 Section 2: Post-Deduplication Metrics</h2>
                
                <h3 style="margin-top: 2rem;">Summary Metrics</h3>
                {metrics_table}
                
                <h3 style="margin-top: 2rem;">Interactive Visualizations</h3>
                {plots_html}
            </div>
            
            <div class="section">
                <h2>💡 Recommendations</h2>
                {recommendations}
            </div>
        </div>
        
        <div class="footer">
            <p>UMI Amplicon Pipeline v1.0.0 | Generated with Plotly</p>
            <p>Interactive plots: Hover for details, click and drag to zoom, double-click to reset</p>
        </div>
    </div>
</body>
</html>'''
    
    # Write HTML file
    with open(output_file, 'w') as f:
        f.write(html)
    
    print(f"Interactive HTML report generated: {output_file}", file=sys.stderr)


def generate_recommendations(metrics: Dict) -> str:
    """Generate automated recommendations based on metrics."""
    recommendations = []
    
    diversity_ratio = metrics.get('diversity_ratio', 0)
    collision_rate = metrics.get('collision_rate', 0)
    mean_family_size = metrics.get('mean_family_size', 0)
    singleton_rate = metrics.get('singleton_rate', 0)
    mean_quality = metrics.get('mean_umi_quality', 0)
    
    # Diversity recommendations
    if diversity_ratio < 0.3:
        recommendations.append("⚠️ <strong>Low diversity</strong>: Consider reducing PCR cycles by 2-3 or increasing starting material")
    elif diversity_ratio > 0.7:
        recommendations.append("✅ <strong>Excellent diversity</strong>: Library complexity is optimal")
    
    # Collision recommendations
    if collision_rate > 0.1:
        recommendations.append("⚠️ <strong>High collision rate</strong>: Consider using longer UMIs (16bp instead of 12bp)")
    
    # Amplification recommendations
    if mean_family_size > 10:
        recommendations.append("⚠️ <strong>Over-amplification</strong>: Reduce PCR cycles to minimize duplication")
    elif mean_family_size < 2:
        recommendations.append("⚠️ <strong>Under-amplification</strong>: Increase PCR cycles or sequencing depth")
    
    # Singleton recommendations
    if singleton_rate > 0.8:
        recommendations.append("⚠️ <strong>High singleton rate</strong>: May indicate insufficient sequencing depth")
    
    # Quality recommendations
    if mean_quality < 20:
        recommendations.append("❌ <strong>Low UMI quality</strong>: Check sequencing quality and consider re-sequencing")
    elif mean_quality >= 30:
        recommendations.append("✅ <strong>Excellent UMI quality</strong>: Sequencing quality is optimal")
    
    if not recommendations:
        recommendations.append("✅ All metrics are within acceptable ranges")
    
    html = '<div class="recommendations"><h3>Recommendations</h3><ul>'
    for rec in recommendations:
        html += f'<li>{rec}</li>'
    html += '</ul></div>'
    
    return html


def main():
    """Main entry point."""
    args = parse_args()
    
    try:
        # Load pre-dedup metrics if provided
        pre_dedup_metrics = {}
        if args.pre_dedup_txt:
            pre_dedup_metrics = parse_pre_dedup_txt(args.pre_dedup_txt)
            print(f"Loaded pre-dedup metrics from text file: {args.pre_dedup_txt}", file=sys.stderr)
            
            # Optionally load JSON for additional plot data
            if args.pre_dedup_json:
                json_data = load_metrics(args.pre_dedup_json)
                # Merge plot_data if available
                if 'plot_data' in json_data:
                    pre_dedup_metrics['plot_data'] = json_data['plot_data']
                print(f"Loaded additional plot data from JSON: {args.pre_dedup_json}", file=sys.stderr)
        elif args.pre_dedup_json:
            # Fallback to JSON only
            pre_dedup_metrics = load_metrics(args.pre_dedup_json)
            print(f"Loaded pre-dedup metrics from JSON: {args.pre_dedup_json}", file=sys.stderr)
        
        # Load post-dedup metrics
        post_dedup_metrics = load_metrics(args.post_dedup_json)
        print(f"Loaded post-dedup metrics from {args.post_dedup_json}", file=sys.stderr)
        
        # Generate report
        generate_html_report(pre_dedup_metrics, post_dedup_metrics, args.sample, args.output)
        
        return 0
        
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
