import os
import pathlib

# Get the project directory as the parent of this module location
src_module_dir = pathlib.Path(os.path.dirname(os.path.abspath(__file__)))
project_dir = pathlib.Path(os.path.dirname(os.path.abspath(__file__))).parent

data_path = project_dir / 'data'
raw_data_path = data_path / 'raw'
interim_data_path = data_path / 'interim'
processed_data_path = data_path / 'processed'

notebooks_path = project_dir / 'notebooks'
references_path = project_dir / 'references'

reports_path = project_dir / 'reports'
figures_path = reports_path / 'figures'
paper_path = reports_path / 'paper'
logs_path = reports_path / 'logs'