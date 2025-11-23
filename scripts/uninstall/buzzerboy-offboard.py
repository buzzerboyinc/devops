#!/usr/bin/env python3
"""
Search the filesystem for files containing specific keywords in their filename.
"""

import os
import sys
from time import time

# Keywords to search for in filenames
SEARCH_KEYWORDS = [
    'buzzerboy',
    'bbi',
    'salutpierre',
    'ironfort'
]

def search_filesystem(root_path='/', keywords=None):
    """
    Search the filesystem for files and directories containing any of the specified keywords in their absolute path.
    
    Args:
        root_path: The root directory to start searching from (default: '/')
        keywords: List of keywords to search for in absolute paths
    """
    if keywords is None:
        keywords = SEARCH_KEYWORDS
    
    printed_paths = set()  # Track what we've already printed to avoid duplicates
    
    for dirpath, dirnames, filenames in os.walk(root_path, topdown=True):
        # Skip certain directories to avoid permission errors and improve performance
        dirnames[:] = [d for d in dirnames if d not in [
            'proc', 'sys', 'dev', 'run', 'tmp', 'var/run', 'var/lock'
        ]]
        
        try:
            # Check if current directory path contains any keyword
            if any(keyword.lower() in dirpath.lower() for keyword in keywords):
                if dirpath not in printed_paths:
                    print(dirpath)
                    printed_paths.add(dirpath)
            
            # Check directory names in their full path
            for dirname in dirnames:
                full_path = os.path.join(dirpath, dirname)
                if any(keyword.lower() in full_path.lower() for keyword in keywords):
                    if full_path not in printed_paths:
                        print(full_path)
                        printed_paths.add(full_path)
            
            # Check file names in their full path
            for filename in filenames:
                full_path = os.path.join(dirpath, filename)
                if any(keyword.lower() in full_path.lower() for keyword in keywords):
                    if full_path not in printed_paths:
                        print(full_path)
                        printed_paths.add(full_path)
        except PermissionError:
            # Skip directories we don't have permission to read
            continue
        except Exception as e:
            # Skip any other errors silently
            continue


def main():
    print("Welcome to Buzzerboy Uninstaller Offboard Search Tool")
    print("-------------------------------------------------\n")
    print("This tool will search your filesystem for files and directories related to Buzzerboy Offboarding.")
    print("You must delete all the files and directories found by this tool to complete the offboarding process. If you think some of the files are false positives, please contact support for assistance." )
    print("Once completed. Please take a screenshot and provide to Buzzerboy Support for verification.")

    os.system('sleep 30')
    
    if len(sys.argv) > 1:
        search_path = sys.argv[1]
    else:
        search_path = '/'
    
    try:
        search_filesystem(search_path, SEARCH_KEYWORDS)
    except KeyboardInterrupt:
        print("\n\nSearch interrupted by user.", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()