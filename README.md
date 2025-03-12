# Advanced PostgreSQL Port Operations Analytics

## Overview
This repository contains a comprehensive collection of advanced PostgreSQL queries designed for analyzing port operations productivity and efficiency metrics. The queries demonstrate sophisticated SQL techniques for monitoring container terminal operations, equipment utilization, and operational performance in real-time.

## Features

### Operational Analytics
- Equipment efficiency and utilization tracking
- Container movement analysis
- Job cycle time monitoring
- Break time and operational status tracking
- Resource utilization patterns
- Productivity metrics by equipment type
- Container size and type analytics

### Technical Capabilities
- Time-series analysis with window functions
- JSON/JSONB data manipulation and aggregation
- Common Table Expressions (CTEs) for complex calculations
- Dynamic temporal calculations and interval handling
- Multi-level data aggregation and reporting
- Equipment state tracking and analysis
- Performance metric calculations

## Query Categories

### Equipment Utilization
- Ignition time tracking
- Login/logout analysis
- Break time monitoring
- Job cycle analysis
- Equipment state transitions

### Productivity Analysis
- Container movement tracking
- Job completion rates
- Equipment-specific productivity metrics
- Container size distribution
- Operational efficiency calculations

### OEE (Overall Equipment Effectiveness)
- Availability tracking
- Performance monitoring
- Quality metrics
- Downtime analysis
- Operational status tracking

## Technical Highlights

### PostgreSQL Features Utilized
- JSONB operators and functions (`->`, `->>`, `jsonb_array_elements`)
- Window functions (`ROW_NUMBER()`, aggregates with `OVER`)
- Array aggregations (`ARRAY_AGG`, `JSON_BUILD_OBJECT`)
- Complex temporal calculations (`INTERVAL`, `EXTRACT`, `DATE_TRUNC`)
- Dynamic interval handling
- Lateral joins
- JSON object construction and manipulation

### Performance Optimization
- Efficient date range filtering
- Optimized join patterns
- Smart use of indexes
- Efficient aggregation strategies
- Temporal data handling optimization

## Schema Overview

### Key Tables
- `bi_job_hist`: Job history and execution details
- `bi_eq_ignition`: Equipment ignition records
- `bi_eq_login`: Equipment login/logout events
- `bi_eq_breaktime`: Equipment break time records
- `bi_oee_tml_value`: Terminal OEE configuration values

## Use Cases

### Terminal Operations
- Real-time equipment tracking
- Productivity monitoring
- Resource utilization optimization
- Performance analysis
- Operational efficiency improvement

### Analytics and Reporting
- Historical performance analysis
- Equipment utilization reports
- Productivity trend analysis
- Resource allocation optimization
- Operational bottleneck identification

## Best Practices
- Consistent use of CTEs for complex logic
- Proper handling of NULL values
- Efficient date/time calculations
- Standardized JSON data handling
- Optimized join strategies
- Clear and maintainable code structure

## Requirements
- PostgreSQL 9.6+
- PostGIS (for spatial operations if needed)
- Appropriate database permissions
- Understanding of port operations domain

This repository serves as both a reference implementation and a practical toolkit for port operations analytics using PostgreSQL's advanced features. 