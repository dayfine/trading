#!/bin/bash

# Navigate to your data directory
cd data

# Loop through all CSV files in the current directory
for file in *.csv; do
    # Extract the filename without extension
    filename="${file%.csv}"

    # Get the first and last characters of the filename
    first_char="${filename:0:1}"
    last_char="${filename: -1}"

    # Create the directory structure if it doesn't exist
    mkdir -p "$first_char/$last_char/$filename"

    # Copy the file to the new location and rename it to data.csv
    cp "$file" "$first_char/$last_char/$filename/data.csv"

    # Optional: remove the original file
    # rm "$file"
done
