import re

KEYWORDS = {'function', 'do', 'then', 'repeat', 'end', 'until', 'for', 'while', 'if', 'elseif', 'continue'}


def _continues(src):
    """Luau `continue` -> `goto __cN`, with `::__cN::` just before that loop's `end`."""
    if not re.search(r'\bcontinue\b', src):
        return src
    edits = []  # (pos, length, replacement)
    stack = []  # entries: [kind, id, used]
    pending = None  # 'loop' after for/while, 'if' / 'elseif' before then
    n, i, ids = len(src), 0, 0
    while i < n:
        c = src[i]
        if c == '-' and src.startswith('--', i):
            m = re.match(r'--\[(=*)\[', src[i:])
            if m:
                close = ']' + m.group(1) + ']'
                j = src.find(close, i)
                i = n if j < 0 else j + len(close)
            else:
                j = src.find('\n', i)
                i = n if j < 0 else j
            continue
        if c in '"\'':
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == '\\' else 1
            i = j + 1
            continue
        if c == '[':
            m = re.match(r'\[(=*)\[', src[i:])
            if m:
                close = ']' + m.group(1) + ']'
                j = src.find(close, i)
                i = n if j < 0 else j + len(close)
                continue
        if c.isalpha() or c == '_':
            m = re.match(r'[A-Za-z_]\w*', src[i:])
            word = m.group(0)
            prev = src[:i].rstrip()[-1:] if i else ''
            if word in KEYWORDS and prev not in ('.', ':'):
                if word in ('for', 'while'):
                    pending = 'loop'
                elif word in ('if', 'elseif'):
                    pending = word
                elif word == 'do':
                    if pending == 'loop':
                        ids += 1
                        stack.append(['loop', ids, False])
                    else:
                        stack.append(['do', 0, False])
                    pending = None
                elif word == 'then':
                    if pending == 'if':
                        stack.append(['if', 0, False])
                    pending = None
                elif word in ('function', 'repeat'):
                    stack.append([word, 0, False])
                elif word in ('end', 'until'):
                    top = stack.pop() if stack else None
                    if top and top[0] == 'loop' and top[2]:
                        edits.append((i, 0, f'::__c{top[1]}:: '))
                elif word == 'continue':
                    loop = next((s for s in reversed(stack) if s[0] in ('loop', 'function', 'repeat')), None)
                    if loop and loop[0] == 'loop':
                        loop[2] = True
                        edits.append((i, len(word), f'goto __c{loop[1]}'))
            i += len(word)
            continue
        i += 1
    for pos, length, rep in sorted(edits, reverse=True):
        src = src[:pos] + rep + src[pos + length:]
    return src


def convert(src):
    src = _continues(src)
    out=[]
    open_iter=None
    for line in src.split('\n'):
        # `_ = x` (silencing an unused value) can hit a read-only loop variable in Lua 5.4
        line=re.sub(r'^(\s*)_ = ', r'\1local _ = ', line)
        m=re.match(r'^(\s*)([\w\.\[\]"\']+(?:\.[\w]+)*)\s*(\+|-|\*|/|\.\.)=\s*(.*)$', line)
        if m and not line.strip().startswith('--'):
            ind,lhs,op,rhs=m.groups()
            line=f'{ind}{lhs} = {lhs} {op} ({rhs})'
        # generalized iteration over a table literal spread across lines
        if open_iter is not None and re.match(r'^' + open_iter + r'\}\s+do\b', line):
            line=line.replace('}', '})', 1)
            open_iter=None
            out.append(line)
            continue
        m=re.match(r'^(\s*)(for\s+[\w\s,]+\s+in\s+)(\{\s*(--.*)?)$', line)
        if m:
            line=f'{m.group(1)}{m.group(2)}__iter({m.group(3)}'
            open_iter=m.group(1)
            out.append(line)
            continue
        # generalized iteration
        m=re.match(r'^(\s*for\s+[\w\s,]+\s+in\s+)(.*)(\s+do\s*(--.*)?)$', line)
        if m:
            head,expr,tail=m.group(1),m.group(2),m.group(3)
            if not re.match(r'^(pairs|ipairs|next|string\.gmatch|\w+:gmatch)\b', expr.strip()):
                line=f'{head}__iter({expr}){tail}'
        out.append(line)
    return '\n'.join(out)
