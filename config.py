import json
from pathlib import Path

class Config:
    def __init__(self):
        self.config_file = Path.home() / ".file_organizer_config.json"
        self.config = self.load_config()

    def load_config(self):
        default_config = {
            "base_dir": str(Path.home() / "OrganizedFiles"),
            "duplicate_handling": "rename",
            "create_date_folders": True,
            "extract_metadata": True,
            "categories": {
                # Categories as defined in the original code
            }
        }
        
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                return json.load(f)
        else:
            self.save_config(default_config)
            return default_config

    def save_config(self, config):
        with open(self.config_file, 'w') as f:
            json.dump(config, f, indent=4)

    # Add other config methods as needed 