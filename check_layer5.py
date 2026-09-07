with open(r'C:\Users\JIM\my_spots\lib\views\widgets\offline_maps\zone_editor_overlay.dart', 'r', encoding='utf-8') as f:
    content = f.read()
if 'Translucent fallback' in content:
    print('LAYER 5 PRESENT')
else:
    print('LAYER 5 ABSENT')

# Also check for IgnorePointer
if 'IgnorePointer' in content:
    print('IgnorePointer PRESENT')
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'IgnorePointer' in line:
            print(f'  L{i+1}: {line.strip()}')
else:
    print('IgnorePointer ABSENT')

# Check for HitTestBehavior.translucent
if 'HitTestBehavior.translucent' in content:
    print('HitTestBehavior.translucent PRESENT')
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'HitTestBehavior.translucent' in line:
            print(f'  L{i+1}: {line.strip()}')
else:
    print('HitTestBehavior.translucent ABSENT')