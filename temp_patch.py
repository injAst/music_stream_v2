import os

file_path = r'd:\Work\Current\Site\MusicStream\music_stream_v2\lib\features\home\discover_tab.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

target = """                             Text(
                               'ETERNAL FLOW ENGINE 3.1',
                               style: GoogleFonts.outfit(
                                 fontSize: 11,
                                 fontWeight: FontWeight.w900,
                                 color: Colors.white.withValues(alpha: 0.7),
                                 letterSpacing: 2.5,
                               ),
                             ),"""

replacement = """                             Expanded(
                               child: Text(
                                 'ETERNAL FLOW ENGINE 3.1',
                                 style: GoogleFonts.outfit(
                                   fontSize: 11,
                                   fontWeight: FontWeight.w900,
                                   color: Colors.white.withValues(alpha: 0.7),
                                   letterSpacing: 2.5,
                                 ),
                                 maxLines: 1,
                                 overflow: TextOverflow.ellipsis,
                               ),
                             ),"""

# Attempt to replace regardless of line endings or slight whitespace differences if needed, 
# but first try exact match from the view_file logic.
if target in content:
    new_content = content.replace(target, replacement)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print("Successfully replaced the text.")
else:
    # Try a more liberal match
    print("Exact match failed. Trying liberal match.")
    import re
    liberal_target = r"Text\(\s+'ETERNAL FLOW ENGINE 3\.1',\s+style: GoogleFonts\.outfit\(\s+fontSize: 11,\s+fontWeight: FontWeight\.w900,\s+color: Colors\.white\.withValues\(alpha: 0\.7\),\s+letterSpacing: 2\.5,\s+\),\s+\),"
    new_content = re.sub(liberal_target, replacement, content, flags=re.DOTALL)
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print("Successfully replaced text using liberal match.")
    else:
        print("Failed to find the target content even with liberal match.")
