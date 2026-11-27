import os
import math
import pandas as pd
import json

def get_file_info(root_folder):
    file_info = []

    def add_folder_contents(folder_path, parent_name):
        # Retrieve contents of the folder
        for root, dirs, files in os.walk(folder_path):
            # Skip any 'env' folder
            dirs[:] = [d for d in dirs if not (d.startswith('myenv') or d.startswith('.'))]
            files[:] = [f for f in files if not f.startswith('.')]

            # Add directories
            for dir_name in dirs:
                dir_path = os.path.join(root, dir_name)
                relative_path = os.path.relpath(dir_path, root_folder)
                folder_name = os.path.basename(dir_path)
                if parent_name:  # Append to the parent
                    file_info.append([f"{parent_name}/{folder_name}", "Folder", ""])
                else:  # Root level folders
                    file_info.append([folder_name, "Folder", ""])
                add_folder_contents(dir_path, f"{parent_name}/{folder_name}" if parent_name else folder_name)

            # Add files
            for file_name in files:
                file_path = os.path.join(root, file_name)
                file_size = os.path.getsize(file_path)
                file_type = file_name.split('.')[-1].lower()
                relative_path = os.path.relpath(file_path, root_folder)
                size_str = format_size(file_size)
                file_info.append([relative_path, file_type, size_str])
            break  # Avoid descending into subfolders again

    add_folder_contents(root_folder, "")
    
    return file_info

def format_size(size):
    if not isinstance(size, (int, float)):
        return ""  # For non-numeric sizes
    
    if size == 0:
        return "0 B"
    
    size_name = ("B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB")
    i = int(math.floor(math.log(size, 1024)))
    p = math.pow(1024, i)
    s = round(size / p, 2)
    return f"{s} {size_name[i]}"

def save_to_json(file_info, output_file):
    # Save as regular JSON format (list of lists)
    json_data = [{"Name": item[0], "Type": item[1], "Size": item[2]} for item in file_info]
    with open(output_file, 'w') as json_file:
        json.dump(json_data, json_file, indent=4)

def save_ai_format_json(file_info, output_file):
    # Save as AI training format (dict with file names as keys)
    ai_data = {item[0]: {"Type": item[1], "Size": item[2]} for item in file_info}
    with open(output_file, 'w') as json_file:
        json.dump(ai_data, json_file, indent=4)

if __name__ == "__main__":
    root_folder = os.getcwd()  # Automatically use the current directory
    folder_name = os.path.basename(root_folder.rstrip('/'))  # Get the current folder name

    # File paths for the two JSON files
    output_file_json = f"{folder_name}_file_info.json"
    output_file_ai_json = f"{folder_name}_file_info_ai_format.json"

    # Get file information
    file_info = get_file_info(root_folder)

    # Save the file information in both JSON formats
    save_to_json(file_info, output_file_json)
    save_ai_format_json(file_info, output_file_ai_json)

    print(f"File information saved to {output_file_json} and {output_file_ai_json}")
