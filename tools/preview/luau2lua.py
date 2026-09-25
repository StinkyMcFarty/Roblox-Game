import re
def convert(src):
    out=[]
    for line in src.split('\n'):
        m=re.match(r'^(\s*)([\w\.\[\]"\']+(?:\.[\w]+)*)\s*(\+|-|\*|/|\.\.)=\s*(.*)$', line)
        if m and not line.strip().startswith('--'):
            ind,lhs,op,rhs=m.groups()
            line=f'{ind}{lhs} = {lhs} {op} ({rhs})'
        # generalized iteration
        m=re.match(r'^(\s*for\s+[\w\s,]+\s+in\s+)(.*)(\s+do\s*(--.*)?)$', line)
        if m:
            head,expr,tail=m.group(1),m.group(2),m.group(3)
            if not re.match(r'^(pairs|ipairs|next|string\.gmatch|\w+:gmatch)\b', expr.strip()):
                line=f'{head}__iter({expr}){tail}'
        out.append(line)
    return '\n'.join(out)
