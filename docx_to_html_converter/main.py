import argparse
import mammoth
from bs4 import BeautifulSoup

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert DOCX to HTML")
    parser.add_argument("source", help="Ruta del archivo .docx de entrada")
    parser.add_argument("destination", help="Ruta del archivo .html de salida")
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    with open(args.source, "rb") as docx_file:
        result = mammoth.convert_to_html(docx_file)
        html: str = result.value

    print("finished html conversion")

    html = BeautifulSoup(html, features="html.parser").prettify()

    print("finished html prettifying")

    # Write with UTF-8 encoding to support non-ASCII characters in the converted HTML.
    with open(args.destination, "w", encoding="utf-8") as html_file:
        html_file.write(html)
