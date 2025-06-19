#!/usr/bin/env python3
"""
Convert GPX track points (trkpt) to waypoints (wpt).
"""

import xml.etree.ElementTree as ET
import sys
import argparse
from pathlib import Path


def convert_trkpt_to_wpt(input_file, output_file):
    """Convert track points to waypoints in a GPX file."""
    
    # Parse the input GPX file
    tree = ET.parse(input_file)
    root = tree.getroot()
    
    # Define GPX namespace
    ns = {'gpx': 'http://www.topografix.com/GPX/1/1'}
    
    # Create new GPX root for output
    new_root = ET.Element('gpx')
    new_root.set('version', '1.1')
    new_root.set('creator', 'GPX Converter')
    new_root.set('xmlns', 'http://www.topografix.com/GPX/1/1')
    
    waypoint_count = 0
    
    # Find all track points
    for trk in root.findall('.//gpx:trk', ns):
        for trkseg in trk.findall('.//gpx:trkseg', ns):
            for trkpt in trkseg.findall('.//gpx:trkpt', ns):
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
    output_tree.write(output_file, encoding='utf-8', xml_declaration=True)
    
    print(f"Converted {waypoint_count} track points to waypoints")
    print(f"Output written to: {output_file}")


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