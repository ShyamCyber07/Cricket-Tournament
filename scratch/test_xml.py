import xml.etree.ElementTree as ET
import re

xml_path = r"c:\Users\praja\Desktop\Cricket\scratch\dump.xml"
with open(xml_path, 'r', encoding='utf-8') as f:
    content = f.read()

print("XML content length:", len(content))
try:
    root = ET.fromstring(content)
    print("Parsed root tag:", root.tag)
    
    nodes = list(root.iter('node'))
    print("Total nodes:", len(nodes))
    
    for i, node in enumerate(nodes):
        cls = node.get('class')
        text = node.get('text')
        desc = node.get('content-desc')
        bounds = node.get('bounds')
        if 'EditText' in cls or 'Button' in cls or text or desc:
            print(f"Node {i}: class={cls}, text='{text}', desc='{desc}', bounds={bounds}")
            
except Exception as e:
    print("Error parsing XML:", e)
