# Setup

1. Create .venv folder:

        python -m venv .venv

1. Activate virtual environment:

    - On Windows:

            Set-ExecutionPolicy Bypass

            ./.venv/Scripts/Activate.ps1
            
    - On Unix or MacOS:

            source .venv/bin/activate

1. Install dependencies:

        pip install -r requirements.txt

1. Install development dependencies:

        pip install -r requirements-dev.txt

# Build

    pyinstaller main.py --name=docx_to_html --onefile