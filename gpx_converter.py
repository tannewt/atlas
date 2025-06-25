#!/usr/bin/env python3
"""
Convert GPX track points (trkpt) to waypoints (wpt).
"""

import xml.etree.ElementTree as ET
import sys
import argparse
from pathlib import Path
from datetime import datetime, timedelta


def convert_trkpt_to_wpt(input_file, output_file):
    """Convert track points to waypoints in a GPX file, split into 120-second chunks."""
    
    # Parse the input GPX file
    tree = ET.parse(input_file)
    root = tree.getroot()
    
    # Define GPX namespace
    ns = {'gpx': 'http://www.topografix.com/GPX/1/1'}
    
    # Collect all track points with timestamps
    track_points = []
    
    # Find all track points
    for trk in root.findall('.//gpx:trk', ns):
        for trkseg in trk.findall('.//gpx:trkseg', ns):
            for trkpt in trkseg.findall('.//gpx:trkpt', ns):
                # Try with namespace first, then without
                time_elem = trkpt.find('gpx:time', ns)
                if time_elem is not None:
                    # Handle ISO format with Z suffix
                    time_str = time_elem.text.replace("Z", "0")
                    print(repr(time_str))
                    timestamp = datetime.fromisoformat(time_str)
                    track_points.append((timestamp, trkpt))
    
    if not track_points:
        print("No track points with valid timestamps found")
        return
    
    # Sort by timestamp
    track_points.sort(key=lambda x: x[0])
    
    # Split into 120-second chunks
    chunk_duration = timedelta(seconds=120)
    chunk_start = track_points[0][0]
    chunk_number = 1
    current_chunk = []
    total_waypoints = 0
    
    for timestamp, trkpt in track_points:
        # Check if we need to start a new chunk
        if timestamp >= chunk_start + chunk_duration:
            # Write current chunk if it has points
            if current_chunk:
                write_chunk(current_chunk, output_file, chunk_number, ns)
                total_waypoints += len(current_chunk)
                chunk_number += 1
            
            # Start new chunk
            chunk_start = timestamp
            current_chunk = []
        
        current_chunk.append(trkpt)
    
    # Write final chunk
    if current_chunk:
        write_chunk(current_chunk, output_file, chunk_number, ns)
        total_waypoints += len(current_chunk)
    
    print(f"Converted {total_waypoints} track points to waypoints across {chunk_number} files")


def write_chunk(track_points, base_output_file, chunk_number, ns):
    """Write a chunk of track points as waypoints to a separate file."""
    
    # Create output filename with chunk number
    base_path = Path(base_output_file)
    chunk_output = base_path.parent / f"{base_path.stem}_chunk_{chunk_number:02d}.gpx"
    
    # Create new GPX root for output
    new_root = ET.Element('gpx')
    new_root.set('version', '1.1')
    new_root.set('creator', 'GPX Converter')
    new_root.set('xmlns', 'http://www.topografix.com/GPX/1/1')
    
    waypoint_count = 0
    
    for trkpt in track_points:
        # Create waypoint element
        wpt = ET.SubElement(new_root, 'wpt')
        wpt.set('lat', trkpt.get('lat'))
        wpt.set('lon', trkpt.get('lon'))
        
        # Copy elevation if present
        ele = trkpt.find('gpx:ele', ns)
        if ele is not None:
            wpt_ele = ET.SubElement(wpt, 'ele')
            wpt_ele.text = ele.text
        
        # Copy time if present
        time = trkpt.find('gpx:time', ns)
        if time is not None:
            wpt_time = ET.SubElement(wpt, 'time')
            wpt_time.text = time.text
        
        # Add name
        name = ET.SubElement(wpt, 'name')
        name.text = f'WPT{waypoint_count:03d}'
        
        waypoint_count += 1
    
    # Write output file
    output_tree = ET.ElementTree(new_root)
    ET.indent(output_tree, space='  ')
    output_tree.write(chunk_output, encoding='utf-8', xml_declaration=True)
    
    print(f"Chunk {chunk_number}: {waypoint_count} waypoints -> {chunk_output}")


def main():
    parser = argparse.ArgumentParser(description='Convert GPX track points to waypoints')
    parser.add_argument('input', help='Input GPX file')
    parser.add_argument('-o', '--output', help='Output GPX file (default: input_waypoints.gpx)')
    
    args = parser.parse_args()
    
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file '{args.input}' not found")
        sys.exit(1)
    
    if args.output:
        output_path = Path(args.output)
    else:
        output_path = input_path.parent / f"{input_path.stem}_waypoints.gpx"
    
    try:
        convert_trkpt_to_wpt(input_path, output_path)
    except Exception as e:
        print(f"Error converting file: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()