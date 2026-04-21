import re

with open('analyze_output.txt', 'r', encoding='utf-8') as f:
    lines = f.readlines()

for line in lines:
    if 'invalid_constant' in line:
        parts = line.strip().split(' - ')
        if len(parts) >= 3:
            file_loc = parts[2].split(':')
            if len(file_loc) >= 2:
                file_path = file_loc[0].strip()
                line_no = int(file_loc[1].strip()) - 1
                try:
                    with open(file_path, 'r', encoding='utf-8') as tf:
                        target_lines = tf.readlines()
                    if 'const' in target_lines[line_no]:
                        target_lines[line_no] = target_lines[line_no].replace('const ', '')
                    with open(file_path, 'w', encoding='utf-8') as tf:
                        tf.writelines(target_lines)
                except Exception as e:
                    print(f'Error processing {file_path}:{line_no}: {e}')
