import re
from collections import defaultdict

def main():
    try:
        with open('analysis_output.txt', 'r', encoding='utf-16') as f:
            content = f.read()
    except Exception:
        with open('analysis_output.txt', 'r', encoding='utf-8') as f:
            content = f.read()

    lines = content.splitlines()
    files_with_warnings = defaultdict(list)
    for line in lines:
        line = line.strip()
        # Format: severity - message - filepath:line:col - rule
        # e.g., info - 'withOpacity' is deprecated... - lib\widgets\bedtime_overlay.dart:49:37 - deprecated_member_use
        parts = line.split(' - ')
        if len(parts) >= 4:
            severity = parts[0].strip()
            if severity in ('info', 'warning', 'error'):
                rule = parts[-1].strip()
                file_info = parts[-2].strip()
                # extract file name (may contain spaces)
                file_match = re.match(r'^(.*?\.dart):\d+:\d+$', file_info)
                if file_match:
                    filepath = file_match.group(1)
                    files_with_warnings[filepath].append(rule)

    print(f"TOTAL FILES WITH WARNINGS: {len(files_with_warnings)}")
    for filepath, warnings in sorted(files_with_warnings.items()):
        counts = defaultdict(int)
        for w in warnings:
            counts[w] += 1
        rules_str = ", ".join(f"{rule}: {count}" for rule, count in counts.items())
        print(f"{filepath}: {rules_str}")

if __name__ == '__main__':
    main()
