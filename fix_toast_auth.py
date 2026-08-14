import re

filepath = r"c:\Users\HP\Desktop\27 may\myridedriverappletest\lib\controllers\auth_controller.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# We want to replace occurrences of AnimatedTopToast.show(...) that are not already inside if (context.mounted)
# Because AnimatedTopToast.show is always followed by a multiline call, we can use a regex that matches the whole statement.

pattern = re.compile(r'(\s*)(AnimatedTopToast\.show\([^;]+;\))')

def repl(match):
    indent = match.group(1)
    toast_call = match.group(2)
    # Check if we already have context.mounted
    # We can just look a bit behind if needed, but it's simpler to just wrap it
    # We will wrap it with if (context.mounted)
    
    # We need to indent the toast call properly
    indented_call = toast_call.replace('\n', '\n    ')
    
    return f'{indent}if (context.mounted) {{\n{indent}    {indented_call}\n{indent}}}'

# Only do it for auth_controller.dart
new_content = pattern.sub(repl, content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Fixed AnimatedTopToast in auth_controller.dart")
