#This python file will define dictionaries for directories, files, and file contents to be verified.
#It will also define functions to verify the existence of these directories and files, as well as the contents of the files.
#It is python focused but not django specific.


import os
import re
import logging
from typing import Dict, List, Tuple


WARNING_CONSOLE_COLOR = '\033[93m'
ERROR_CONSOLE_COLOR = '\033[91m'
RESET_CONSOLE_COLOR = '\033[0m'



DIRS_TO_VERIFY = {
    'app': '{{repo_root}}/{{app_name}}',
    'pipelines': '{{repo_root}}/pipelines',
    'architecture': '{{repo_root}}/architecture',
    'dev_architecture': '{{repo_root}}/architecture/dev',
    'dev_cdktf_import': '{{repo_root}}/architecture/dev/imports',
    'prd_architecture': '{{repo_root}}/architecture/prd',
    'prd_cdktf_import': '{{repo_root}}/architecture/prd/imports',
    'demo_architecture': '{{repo_root}}/architecture/demo',
    'demo_cdktf_import': '{{repo_root}}/architecture/demo/imports',
    'docs': '{{repo_root}}/docs',
    'core': '{{repo_root}}/{{app_name}}/core',
    'html5_ui': '{{repo_root}}/{{app_name}}/html5_ui',
    'fixtures': '{{repo_root}}/{{app_name}}/fixtures',
    'loaders': '{{repo_root}}/{{app_name}}/loaders',
}

FILES_TO_VERIFY = {
    'manage.py': '{{repo_root}}/{{app_name}}/manage.py',
    'Dockerfile': '{{repo_root}}/{{app_name}}/Dockerfile',
    'requirements.txt': '{{repo_root}}/{{app_name}}/requirements.txt',
    'settings.py': '{{repo_root}}/{{app_name}}/{{app_name}}/core/settings.py',
    'LoadAllFixtures.py': '{{repo_root}}/{{app_name}}/loaders/LoadAllFixtures.py',
    'base.html': '{{repo_root}}/{{app_name}}/html5_ui/includes/base.html',
    'index.html': '{{repo_root}}/{{app_name}}/html5_ui/index.html',
    'README.md': '{{repo_root}}/README.md',
    '.gitignore': '{{repo_root}}/.gitignore',
    'dev_cdktf_json': '{{repo_root}}/architecture/dev/cdktf.json',
    'prd_cdktf_json': '{{repo_root}}/architecture/prd/cdktf.json',
    'demo_cdktf_json': '{{repo_root}}/architecture/demo/cdktf.json',
    'dev_main_py': '{{repo_root}}/architecture/dev/main.py',
    'prd_main_py': '{{repo_root}}/architecture/prd/main.py',
    'demo_main_py': '{{repo_root}}/architecture/demo/main.py',
    'architecture_requirements.txt': '{{repo_root}}/architecture/requirements.txt',
    'dev_definition.py': '{{repo_root}}/architecture/dev/definition.py',
    'prd_definition.py': '{{repo_root}}/architecture/prd/definition.py',
    'demo_definition.py': '{{repo_root}}/architecture/demo/definition.py',
}

WARNINGS_ONLY = {
    'prd_architecture': "WARNING",
    'demo_architecture': "WARNING",
    'prd_cdktf_import': "WARNING",
    'demo_cdktf_import': "WARNING",
    'prd_cdktf_json': "WARNING",
    'demo_cdktf_json': "WARNING",
    'prd_main_py': "WARNING",
    'demo_main_py': "WARNING",
    'prd_definition.py': "WARNING",
    'demo_definition.py': "WARNING",
}

warnings = []
errors = []

app = os.environ.get('app', None)
product = os.environ.get('product', None)
repoName = os.environ.get('repoName', None)
rootDir = os.environ.get('rootDir', None)

if rootDir is None:
    rootDir = os.getcwd()


if app is None or product is None or repoName is None:
    raise ValueError("Environment variables 'app', 'product', and 'repoName' must be set.")

repoRoot = os.path.join(rootDir, repoName) 

for key in DIRS_TO_VERIFY:
    DIRS_TO_VERIFY[key] = DIRS_TO_VERIFY[key].replace('{{app_name}}', app)
    DIRS_TO_VERIFY[key] = DIRS_TO_VERIFY[key].replace('{{product_name}}', product)
    DIRS_TO_VERIFY[key] = DIRS_TO_VERIFY[key].replace('{{repo_root}}', repoRoot)
    DIRS_TO_VERIFY[key] = DIRS_TO_VERIFY[key].replace('{{repo_name}}', repoName)

for key in FILES_TO_VERIFY:
    FILES_TO_VERIFY[key] = FILES_TO_VERIFY[key].replace('{{app_name}}', app)
    FILES_TO_VERIFY[key] = FILES_TO_VERIFY[key].replace('{{product_name}}', product)
    FILES_TO_VERIFY[key] = FILES_TO_VERIFY[key].replace('{{repo_root}}', repoRoot)
    FILES_TO_VERIFY[key] = FILES_TO_VERIFY[key].replace('{{repo_name}}', repoName)


def main():
    # grab environment variables and update paths in directories and files and then print them out
    print("Directories to verify:")
    for dir_name, dir_path in DIRS_TO_VERIFY.items():
        print(f"{dir_name}: {dir_path}")
        #does directory exist?
        if not os.path.exists(dir_path):
            if dir_name in WARNINGS_ONLY:
                warnings.append(f"WARNING: Missing directory '{dir_name}' at {dir_path} will be a warning only.")
            else:
                errors.append(f"ERROR: Directory '{dir_name}' at {dir_path} is missing.")

    print("\nFiles to verify:")         
    for file_name, file_path in FILES_TO_VERIFY.items():
        print(f"{file_name}: {file_path}")
        #does file exist?
        if not os.path.exists(file_path):
            if file_name in WARNINGS_ONLY:
                warnings.append(f"WARNING: Missing file '{file_name}' at {file_path} will be a warning only.")
            else:
                errors.append(f"ERROR: File '{file_name}' at {file_path} is missing.")


    if warnings:
        print("\nWarnings:")
        for warning in warnings:
            print(f"{WARNING_CONSOLE_COLOR}{warning}{RESET_CONSOLE_COLOR}")
    

    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"{ERROR_CONSOLE_COLOR}{error}{RESET_CONSOLE_COLOR}")
        raise Exception("Verification failed due to errors.")
    


if __name__ == "__main__":
    main()