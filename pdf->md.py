from docling.document_converter import DocumentConverter

pdf = "TPEspecial2026-1.pdf"

converter = DocumentConverter()
result = converter.convert(pdf)

with open("documento.md", "w", encoding="utf-8") as f:
    f.write(result.document.export_to_markdown())

print("Listo")