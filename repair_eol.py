import difflib
import subprocess

def read_lines(filename):
    with open(filename, 'rb') as f:
        return f.readlines()

def repair():
    head_bytes = subprocess.check_output(['git', 'show', 'HEAD:optiflow_back/optimizer.py'])
    
    # Split by the actual line endings present while keeping them.
    # It's safer to use splitlines(keepends=True) on the bytes.
    head_lines = head_bytes.splitlines(keepends=True)
    current_lines = read_lines('optiflow_back/optimizer.py')

    head_str_lines = [l.decode('utf-8').rstrip('\r\n') for l in head_lines]
    current_str_lines = [l.decode('utf-8').rstrip('\r\n') for l in current_lines]

    sm = difflib.SequenceMatcher(None, head_str_lines, current_str_lines)
    
    out_lines = []
    
    default_eol = b'\n'
    if head_lines and head_lines[0].endswith(b'\r\n'):
        default_eol = b'\r\n'

    for opcode, i1, i2, j1, j2 in sm.get_opcodes():
        if opcode == 'equal':
            for i in range(i1, i2):
                out_lines.append(head_lines[i])
        elif opcode == 'insert':
            eol = default_eol
            if i1 > 0:
                if head_lines[i1-1].endswith(b'\r\n'): eol = b'\r\n'
                elif head_lines[i1-1].endswith(b'\n'): eol = b'\n'
            elif i1 < len(head_lines):
                if head_lines[i1].endswith(b'\r\n'): eol = b'\r\n'
                elif head_lines[i1].endswith(b'\n'): eol = b'\n'
                
            for j in range(j1, j2):
                text = current_str_lines[j].encode('utf-8')
                out_lines.append(text + eol)
        elif opcode == 'replace' or opcode == 'delete':
            print(f"Warning: {opcode} at head[{i1}:{i2}] current[{j1}:{j2}]")
            for j in range(j1, j2):
                text = current_str_lines[j].encode('utf-8')
                out_lines.append(text + default_eol)

    with open('optiflow_back/optimizer.py', 'wb') as f:
        for l in out_lines:
            f.write(l)

repair()
